import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SubjectTimerProvider with ChangeNotifier {
  final List<String> _subjects = [];
  final Map<String, Stopwatch> _timers = {};
  final Map<String, String> _elapsedTimes = {};
  final Map<String, Timer?> _updateTimers = {};
  late Timer _totalUpdateTimer; // 전체 시간 업데이트를 위한 타이머
  late SharedPreferences _prefs;

  String _totalElapsedTime = "00:00:00";
  String get totalElapsedTime => _totalElapsedTime;

  // Getter
  Map<String, String> get elapsedTimes => _elapsedTimes;
  List<String> get subjects => List.unmodifiable(_subjects);
  Map<String, Stopwatch> get timers => _timers;


  SubjectTimerProvider() {
    // 전체 시간 업데이트 타이머 초기화
    _totalUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _updateTotalElapsedTime(),
    );
  }

  // 전체 시간과 과목 시간 초기화 메서드
  void resetAll() {
    // 전체 시간 초기화
    _totalElapsedTime = "00:00:00";

    // 각 과목의 타이머와 경과 시간 초기화
    _timers.forEach((subjectName, stopwatch) {
      stopwatch.reset();
      _elapsedTimes[subjectName] = "00:00:00";
    });

    // 초기화 후 상태 갱신
    notifyListeners();
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSavedTimers();

    // 기본 과목 추가
    if (_subjects.isEmpty) {
      for (var subject in ["과목 1", "과목 2", "과목 3"]) {
        addSubject(subject);
      }
    }
  }

  Future<void> _loadSavedTimers() async {
    final savedTimesJson = _prefs.getString('elapsedTimes');
    if (savedTimesJson != null) {
      final savedTimes = json.decode(savedTimesJson) as Map<String, dynamic>;
      savedTimes.forEach((subjectName, data) {
        final decoded = json.decode(data);
        final elapsedTime = decoded["elapsedTime"];
        final isRunning = decoded["isRunning"];

        // Stopwatch 초기화
        if (!_timers.containsKey(subjectName)) {
          _timers[subjectName] = Stopwatch();
        }

        // 경과 시간 복구
        _elapsedTimes[subjectName] = elapsedTime;

        // 타이머 상태 복구
        if (isRunning) {
          _timers[subjectName]!.start();
          _updateTimers[subjectName] = Timer.periodic(
            const Duration(seconds: 1),
                (_) => _updateElapsedTime(subjectName),
          );
        }
      });
    }
    notifyListeners();
  }

  // 과목 추가
  void addSubject(String subjectName) {
    if (!_timers.containsKey(subjectName)) {
      _timers[subjectName] = Stopwatch();
      _elapsedTimes[subjectName] = "00:00:00";
      _subjects.add(subjectName);
      _saveTimers();
      notifyListeners();
    }
  }

  // 과목 삭제
  void deleteSubject(int index) {
    if (index >= 0 && index < _subjects.length) {
      final subjectName = _subjects[index];
      _timers.remove(subjectName);
      _elapsedTimes.remove(subjectName);
      _subjects.removeAt(index);
      _saveTimers();
      notifyListeners();
    }
  }

  // 과목 이름 수정
  void editSubject(int index, String newName) {
    if (index >= 0 && index < _subjects.length) {
      final oldName = _subjects[index];
      if (oldName != newName) {
        _timers[newName] = _timers.remove(oldName)!;
        _elapsedTimes[newName] = _elapsedTimes.remove(oldName)!;
        _subjects[index] = newName;
        _saveTimers();
        notifyListeners();
      }
    }
  }

  // 타이머 시작
  void startTimer(String subjectName) {
    if (!_timers.containsKey(subjectName)) {
      _timers[subjectName] = Stopwatch();
    }
    final stopwatch = _timers[subjectName]!;
    if (!stopwatch.isRunning) {
      stopwatch.start();
      _updateTimers[subjectName] = Timer.periodic(
        const Duration(seconds: 1),
            (_) => _updateElapsedTime(subjectName),
      );
      notifyListeners();
    }
  }

  // 타이머 중지
  void stopTimer(String subjectName) {
    if (_timers.containsKey(subjectName)) {
      final stopwatch = _timers[subjectName]!;
      if (stopwatch.isRunning) {
        stopwatch.stop();
        _updateTimers[subjectName]?.cancel();
        _updateElapsedTime(subjectName); // 타이머 멈출 때 경과 시간 저장
        notifyListeners();
      }
    }
  }

  // 타이머 리셋
  void resetTimer(String subjectName) {
    if (_timers.containsKey(subjectName)) {
      _timers[subjectName]!.reset();
      _elapsedTimes[subjectName] = "00:00:00"; // 시간 리셋
      notifyListeners(); // 상태 변경 알림
    }
  }

  // 경과 시간 업데이트
  void _updateElapsedTime(String subjectName) {
    if (_timers.containsKey(subjectName)) {
      final stopwatch = _timers[subjectName]!;
      final elapsed = stopwatch.elapsed;
      _elapsedTimes[subjectName] = _formatDuration(elapsed);
      notifyListeners(); // 상태 변경 알림
    }
  }

  // 전체 시간 업데이트
  void _updateTotalElapsedTime() {
    // 모든 타이머의 총 경과 시간 계산
    int totalMilliseconds = _timers.values.fold(0, (sum, stopwatch) {
      return sum + stopwatch.elapsedMilliseconds;
    });

    _totalElapsedTime = _formatDuration(Duration(milliseconds: totalMilliseconds));
    notifyListeners(); // 전체 시간 상태 변경 알림
  }

  // SharedPreferences에 타이머 저장
  void _saveTimers() {
    final savedTimes = _elapsedTimes.map((key, value) {
      final isRunning = _timers[key]?.isRunning ?? false;
      return MapEntry(
        key,
        json.encode({
          "elapsedTime": value,
          "isRunning": isRunning,
        }),
      );
    });
    _prefs.setString('elapsedTimes', json.encode(savedTimes));
  }

  // 시간 포맷 변환
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  // 시간을 Duration 객체로 변환
  Duration _parseDuration(String time) {
    final parts = time.split(':').map(int.parse).toList();
    return Duration(
      hours: parts[0],
      minutes: parts[1],
      seconds: parts[2],
    );
  }

  @override
  void dispose() {
    _totalUpdateTimer.cancel();
    _updateTimers.values.forEach((timer) => timer?.cancel());
    super.dispose();
  }

  // 진행 상황 비율 계산
  double get progress {
    if (_elapsedTimes.isEmpty) return 0.0;

    final totalElapsed = _timers.values
        .map((stopwatch) => stopwatch.elapsedMilliseconds)
        .fold<int>(0, (sum, current) => sum + current);

    const int maxTime = 8 * 60 * 60 * 1000; // 8시간
    return (totalElapsed / maxTime).clamp(0.0, 1.0);
  }
}
