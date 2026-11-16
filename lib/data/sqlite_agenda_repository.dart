import 'package:sqflite/sqflite.dart';

import '../domain/entities.dart';
import 'agenda_repository.dart';

/// Persistência local em SQLite (RNF02), com as entidades da Tabela 5.
///
/// Datas são gravadas como milissegundos desde a época (horário local) e
/// booleanos como 0/1, porque o SQLite não tem tipos próprios para eles.
class SqliteAgendaRepository implements AgendaRepository {
  SqliteAgendaRepository._(this._db);

  final Database _db;

  static const int schemaVersion = 1;

  static Future<SqliteAgendaRepository> open(
    DatabaseFactory factory, {
    String path = 'agenda_ia.db',
  }) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          final batch = db.batch();
          for (final statement in _schema) {
            batch.execute(statement);
          }
          await batch.commit(noResult: true);
        },
      ),
    );
    return SqliteAgendaRepository._(db);
  }

  static const List<String> _schema = [
    '''
    CREATE TABLE compromisso (
      id TEXT PRIMARY KEY,
      titulo TEXT NOT NULL,
      inicio INTEGER NOT NULL,
      fim INTEGER NOT NULL,
      local TEXT,
      CHECK (fim > inicio)
    )''',
    '''
    CREATE TABLE tarefa (
      id TEXT PRIMARY KEY,
      titulo TEXT NOT NULL,
      tipo TEXT NOT NULL CHECK (tipo IN ('foco', 'leve')),
      duracao_estimada INTEGER NOT NULL CHECK (duracao_estimada > 0),
      prazo INTEGER NOT NULL,
      urgente INTEGER NOT NULL,
      importante INTEGER NOT NULL,
      prioridade_manual INTEGER CHECK (prioridade_manual BETWEEN 1 AND 4),
      status TEXT NOT NULL,
      criada_em INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE planejamento (
      id TEXT PRIMARY KEY,
      gerado_em INTEGER NOT NULL,
      algoritmo TEXT NOT NULL,
      custo_total REAL NOT NULL,
      atraso_total INTEGER NOT NULL,
      tempo_execucao_ms REAL NOT NULL,
      nos_expandidos INTEGER NOT NULL,
      otimo INTEGER NOT NULL,
      nao_alocadas TEXT NOT NULL
    )''',
    '''
    CREATE TABLE alocacao (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_tarefa TEXT NOT NULL,
      titulo TEXT NOT NULL,
      inicio INTEGER NOT NULL,
      fim INTEGER NOT NULL,
      parte INTEGER NOT NULL,
      total_partes INTEGER NOT NULL,
      id_planejamento TEXT NOT NULL
        REFERENCES planejamento(id) ON DELETE CASCADE
    )''',
    '''
    CREATE TABLE historico_duracao (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_tarefa TEXT NOT NULL,
      tipo TEXT NOT NULL,
      duracao_estimada INTEGER NOT NULL,
      duracao_real INTEGER NOT NULL,
      registrado_em INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE preferencias (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      inicio_trabalho INTEGER NOT NULL,
      fim_trabalho INTEGER NOT NULL,
      inicio_pico INTEGER NOT NULL,
      fim_pico INTEGER NOT NULL,
      alfa REAL NOT NULL,
      beta REAL NOT NULL,
      limite_nos INTEGER NOT NULL,
      horizonte_dias INTEGER NOT NULL
    )''',
  ];

  Future<void> close() => _db.close();

  // ---------------------------------------------------------------- leitura

  @override
  Future<AgendaSnapshot> loadAll() async {
    final tasks = (await _db.query('tarefa', orderBy: 'criada_em')).map(_taskFrom).toList();
    final events = (await _db.query('compromisso', orderBy: 'inicio')).map(_eventFrom).toList();
    final history = (await _db.query('historico_duracao', orderBy: 'id')).map(_recordFrom).toList();
    final prefsRows = await _db.query('preferencias', where: 'id = 1');
    final prefs = prefsRows.isEmpty ? const Preferences() : _prefsFrom(prefsRows.first);
    return AgendaSnapshot(
      tasks: tasks,
      events: events,
      history: history,
      preferences: prefs,
      currentPlan: await _loadCurrentPlan(),
    );
  }

  Future<PlanRecord?> _loadCurrentPlan() async {
    final rows = await _db.query('planejamento', orderBy: 'gerado_em DESC', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final id = row['id'] as String;
    final allocations = (await _db.query('alocacao',
            where: 'id_planejamento = ?', whereArgs: [id], orderBy: 'inicio'))
        .map((a) => Allocation(
              taskId: a['id_tarefa'] as String,
              title: a['titulo'] as String,
              start: _date(a['inicio']),
              end: _date(a['fim']),
              part: a['parte'] as int,
              partCount: a['total_partes'] as int,
            ))
        .toList();
    final unscheduled = (row['nao_alocadas'] as String)
        .split(',')
        .where((s) => s.isNotEmpty)
        .toList();
    return PlanRecord(
      id: id,
      createdAt: _date(row['gerado_em']),
      algorithm: Algorithm.values.byName(row['algoritmo'] as String),
      totalCost: (row['custo_total'] as num).toDouble(),
      totalTardinessMinutes: row['atraso_total'] as int,
      elapsedMilliseconds: (row['tempo_execucao_ms'] as num).toDouble(),
      expandedNodes: row['nos_expandidos'] as int,
      optimal: row['otimo'] == 1,
      allocations: allocations,
      unscheduledTaskIds: unscheduled,
    );
  }

  // ---------------------------------------------------------------- escrita

  @override
  Future<void> upsertTask(Task task) => _db.insert('tarefa', _taskTo(task),
      conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> deleteTask(String id) async {
    await _db.transaction((txn) async {
      await txn.delete('alocacao', where: 'id_tarefa = ?', whereArgs: [id]);
      await txn.delete('tarefa', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> upsertEvent(FixedEvent event) => _db.insert(
        'compromisso',
        {
          'id': event.id,
          'titulo': event.title,
          'inicio': event.start.millisecondsSinceEpoch,
          'fim': event.end.millisecondsSinceEpoch,
          'local': event.location,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> deleteEvent(String id) =>
      _db.delete('compromisso', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> addDurationRecord(DurationRecord record) => _db.insert('historico_duracao', {
        'id_tarefa': record.taskId,
        'tipo': record.type.name,
        'duracao_estimada': record.estimatedMinutes,
        'duracao_real': record.actualMinutes,
        'registrado_em': record.recordedAt.millisecondsSinceEpoch,
      });

  @override
  Future<void> savePreferences(Preferences p) => _db.insert(
        'preferencias',
        {
          'id': 1,
          'inicio_trabalho': p.workStartMinutes,
          'fim_trabalho': p.workEndMinutes,
          'inicio_pico': p.peakStartMinutes,
          'fim_pico': p.peakEndMinutes,
          'alfa': p.alpha,
          'beta': p.beta,
          'limite_nos': p.nodeLimit,
          'horizonte_dias': p.horizonDays,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> savePlan(PlanRecord plan) async {
    await _db.transaction((txn) async {
      await txn.insert('planejamento', {
        'id': plan.id,
        'gerado_em': plan.createdAt.millisecondsSinceEpoch,
        'algoritmo': plan.algorithm.name,
        'custo_total': plan.totalCost,
        'atraso_total': plan.totalTardinessMinutes,
        'tempo_execucao_ms': plan.elapsedMilliseconds,
        'nos_expandidos': plan.expandedNodes,
        'otimo': plan.optimal ? 1 : 0,
        'nao_alocadas': plan.unscheduledTaskIds.join(','),
      });
      for (final a in plan.allocations) {
        await txn.insert('alocacao', {
          'id_tarefa': a.taskId,
          'titulo': a.title,
          'inicio': a.start.millisecondsSinceEpoch,
          'fim': a.end.millisecondsSinceEpoch,
          'parte': a.part,
          'total_partes': a.partCount,
          'id_planejamento': plan.id,
        });
      }
    });
  }

  @override
  Future<void> deleteAllocationsOf(String taskId) async {
    final rows = await _db.query('planejamento', columns: ['id'], orderBy: 'gerado_em DESC', limit: 1);
    if (rows.isEmpty) return;
    await _db.delete('alocacao',
        where: 'id_tarefa = ? AND id_planejamento = ?',
        whereArgs: [taskId, rows.first['id']]);
  }

  @override
  Future<void> clearAll() async {
    await _db.transaction((txn) async {
      for (final table in [
        'alocacao',
        'planejamento',
        'historico_duracao',
        'tarefa',
        'compromisso',
        'preferencias',
      ]) {
        await txn.delete(table);
      }
    });
  }

  // ------------------------------------------------------------- conversões

  static DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);

  static Map<String, Object?> _taskTo(Task t) => {
        'id': t.id,
        'titulo': t.title,
        'tipo': t.type.name,
        'duracao_estimada': t.estimatedMinutes,
        'prazo': t.deadline.millisecondsSinceEpoch,
        'urgente': t.urgent ? 1 : 0,
        'importante': t.important ? 1 : 0,
        'prioridade_manual': t.priorityOverride,
        'status': t.status.name,
        'criada_em': t.createdAt.millisecondsSinceEpoch,
      };

  static Task _taskFrom(Map<String, Object?> r) => Task(
        id: r['id'] as String,
        title: r['titulo'] as String,
        type: TaskType.values.byName(r['tipo'] as String),
        estimatedMinutes: r['duracao_estimada'] as int,
        deadline: _date(r['prazo']),
        urgent: r['urgente'] == 1,
        important: r['importante'] == 1,
        priorityOverride: r['prioridade_manual'] as int?,
        status: TaskStatus.values.byName(r['status'] as String),
        createdAt: _date(r['criada_em']),
      );

  static FixedEvent _eventFrom(Map<String, Object?> r) => FixedEvent(
        id: r['id'] as String,
        title: r['titulo'] as String,
        start: _date(r['inicio']),
        end: _date(r['fim']),
        location: r['local'] as String?,
      );

  static DurationRecord _recordFrom(Map<String, Object?> r) => DurationRecord(
        taskId: r['id_tarefa'] as String,
        type: TaskType.values.byName(r['tipo'] as String),
        estimatedMinutes: r['duracao_estimada'] as int,
        actualMinutes: r['duracao_real'] as int,
        recordedAt: _date(r['registrado_em']),
      );

  static Preferences _prefsFrom(Map<String, Object?> r) => Preferences(
        workStartMinutes: r['inicio_trabalho'] as int,
        workEndMinutes: r['fim_trabalho'] as int,
        peakStartMinutes: r['inicio_pico'] as int,
        peakEndMinutes: r['fim_pico'] as int,
        alpha: (r['alfa'] as num).toDouble(),
        beta: (r['beta'] as num).toDouble(),
        nodeLimit: r['limite_nos'] as int,
        horizonDays: r['horizonte_dias'] as int,
      );
}
