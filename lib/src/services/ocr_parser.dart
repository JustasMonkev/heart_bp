class OcrParseResult {
  const OcrParseResult({
    required this.rawText,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.score = 0,
  });

  final String rawText;
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final int score;

  OcrParseResult copyWith({
    String? rawText,
    int? systolic,
    int? diastolic,
    int? pulse,
    int? score,
    bool clearSystolic = false,
    bool clearDiastolic = false,
    bool clearPulse = false,
  }) {
    return OcrParseResult(
      rawText: rawText ?? this.rawText,
      systolic: clearSystolic ? null : (systolic ?? this.systolic),
      diastolic: clearDiastolic ? null : (diastolic ?? this.diastolic),
      pulse: clearPulse ? null : (pulse ?? this.pulse),
      score: score ?? this.score,
    );
  }
}

class OcrParser {
  OcrParseResult parse(String rawText) {
    final normalized = rawText.toUpperCase();

    final labeledSystolic = _findLabeledMetric(
      normalized,
      labelPattern: r'(?:SYS|SYSTOLIC)',
      min: 50,
      max: 260,
    );
    final labeledDiastolic = _findLabeledMetric(
      normalized,
      labelPattern: r'(?:DIA|DIASTOLIC)',
      min: 30,
      max: 180,
    );
    final labeledPulse = _findLabeledMetric(
      normalized,
      labelPattern: r'(?:PULSE|PR)',
      min: 30,
      max: 220,
    );

    final excludedValues = <int>{};
    if (labeledSystolic != null) {
      excludedValues.add(labeledSystolic);
    }
    if (labeledDiastolic != null) {
      excludedValues.add(labeledDiastolic);
    }
    if (labeledPulse != null) {
      excludedValues.add(labeledPulse);
    }

    final fallback = _FallbackMetricParser.fromRawText(
      rawText,
      parser: this,
      excludedValues: excludedValues,
    );

    final systolic = labeledSystolic ?? fallback.systolic;
    final diastolic = labeledDiastolic ?? fallback.diastolic;
    final pulse = labeledPulse ?? fallback.pulse;

    return OcrParseResult(
      rawText: rawText,
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      score: _scoreResult(
        systolic: systolic,
        diastolic: diastolic,
        pulse: pulse,
        hasLabeledSystolic: labeledSystolic != null,
        hasLabeledDiastolic: labeledDiastolic != null,
        hasLabeledPulse: labeledPulse != null,
      ),
    );
  }

  OcrParseResult parseBest(Iterable<String> rawTexts) {
    OcrParseResult? best;
    for (final rawText in rawTexts) {
      final parsed = parse(rawText);
      if (best == null || parsed.score > best.score) {
        best = parsed;
      }
    }

    return best ?? const OcrParseResult(rawText: '');
  }

  int? bestMetricValue(
    Iterable<String> rawTexts, {
    required int min,
    required int max,
    int? preferredMin,
    int? preferredMax,
  }) {
    final scores = <int, int>{};
    final tokenPattern = RegExp(r'[A-Z0-9]{1,6}');

    for (final rawText in rawTexts) {
      for (final match in tokenPattern.allMatches(rawText.toUpperCase())) {
        final token = match.group(0)!;
        final value = normalizeMetricToken(token, min: min, max: max);
        if (value == null) {
          continue;
        }

        var score = 10;
        if (preferredMin != null &&
            preferredMax != null &&
            value >= preferredMin &&
            value <= preferredMax) {
          score += 4;
        }
        if (token.length == 2 || token.length == 3) {
          score += 2;
        }

        scores.update(value, (existing) => existing + score, ifAbsent: () => score);
      }
    }

    if (scores.isEmpty) {
      return null;
    }

    final entries = scores.entries.toList()
      ..sort((left, right) {
        final scoreComparison = right.value.compareTo(left.value);
        if (scoreComparison != 0) {
          return scoreComparison;
        }

        final preferredMidpoint = preferredMin != null && preferredMax != null
            ? (preferredMin + preferredMax) / 2
            : null;
        if (preferredMidpoint != null) {
          final leftDistance = (left.key - preferredMidpoint).abs();
          final rightDistance = (right.key - preferredMidpoint).abs();
          final distanceComparison = leftDistance.compareTo(rightDistance);
          if (distanceComparison != 0) {
            return distanceComparison;
          }
        }

        return 0;
      });

    return entries.first.key;
  }

  OcrParseResult mergeTargetedMetrics(
    OcrParseResult base, {
    int? systolic,
    int? diastolic,
    int? pulse,
    String? rawText,
  }) {
    final resolvedSystolic = systolic ?? base.systolic;
    final resolvedDiastolic = diastolic ?? base.diastolic;
    final resolvedPulse = pulse ?? base.pulse;

    return OcrParseResult(
      rawText: rawText ?? base.rawText,
      systolic: resolvedSystolic,
      diastolic: resolvedDiastolic,
      pulse: resolvedPulse,
      score: _scoreResult(
        systolic: resolvedSystolic,
        diastolic: resolvedDiastolic,
        pulse: resolvedPulse,
        hasLabeledSystolic: false,
        hasLabeledDiastolic: false,
        hasLabeledPulse: false,
      ),
    );
  }

  int? normalizeMetricToken(
    String token, {
    required int min,
    required int max,
  }) {
    final normalized = _normalizeDigitLikeToken(token);
    if (normalized == null) {
      return null;
    }

    final value = int.tryParse(normalized);
    if (value == null || value < min || value > max) {
      return null;
    }

    return value;
  }

  int _scoreResult({
    required int? systolic,
    required int? diastolic,
    required int? pulse,
    required bool hasLabeledSystolic,
    required bool hasLabeledDiastolic,
    required bool hasLabeledPulse,
  }) {
    var score = 0;

    if (systolic != null) {
      score += 10;
      if (systolic >= 90 && systolic <= 190) {
        score += 3;
      }
    }
    if (diastolic != null) {
      score += 10;
      if (diastolic >= 50 && diastolic <= 120) {
        score += 3;
      }
    }
    if (pulse != null) {
      score += 10;
      if (pulse >= 40 && pulse <= 120) {
        score += 4;
      }
    }
    if (hasLabeledSystolic) {
      score += 12;
    }
    if (hasLabeledDiastolic) {
      score += 12;
    }
    if (hasLabeledPulse) {
      score += 12;
    }
    if (systolic != null && diastolic != null && pulse != null) {
      score += 18;
    }
    if (systolic != null && diastolic != null && systolic > diastolic) {
      score += 8;
    }

    return score;
  }

  int? _findLabeledMetric(
    String text, {
    required String labelPattern,
    required int min,
    required int max,
  }) {
    final regex = RegExp(
      '$labelPattern[^A-Z0-9]{0,24}([A-Z0-9]{2,4})',
      multiLine: true,
    );
    final match = regex.firstMatch(text);
    if (match == null) {
      return null;
    }

    return normalizeMetricToken(match.group(1)!, min: min, max: max);
  }

  String? _normalizeDigitLikeToken(String token) {
    final cleaned = token.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();
    var digitLikeCount = 0;

    for (final rune in cleaned.runes) {
      final character = String.fromCharCode(rune);
      final mapped = switch (character) {
        '0' || '1' || '2' || '3' || '4' || '5' || '6' || '7' || '8' || '9' =>
          character,
        'O' || 'Q' || 'D' => '0',
        'I' || 'L' => '1',
        'Z' => '2',
        'S' => '5',
        'B' => '8',
        'G' => '6',
        'T' => '7',
        _ => '',
      };

      if (mapped.isEmpty) {
        return null;
      }

      digitLikeCount++;
      buffer.write(mapped);
    }

    if (digitLikeCount < 2) {
      return null;
    }

    return buffer.toString();
  }
}

class _FallbackMetricParser {
  const _FallbackMetricParser({
    this.systolic,
    this.diastolic,
    this.pulse,
  });

  factory _FallbackMetricParser.fromRawText(
    String rawText, {
    required OcrParser parser,
    required Set<int> excludedValues,
  }) {
    final candidates = <int>[];
    final regex = RegExp(r'\b[A-Z0-9]{2,4}\b');

    for (final match in regex.allMatches(rawText.toUpperCase())) {
      final value = parser.normalizeMetricToken(
        match.group(0)!,
        min: 30,
        max: 260,
      );
      if (value != null && !excludedValues.contains(value)) {
        candidates.add(value);
      }
    }

    final pulseCandidates =
        candidates.where((value) => value >= 30 && value <= 220).toList()
          ..sort();
    final pressureCandidates =
        candidates.where((value) => value >= 30 && value <= 260).toList()
          ..sort((left, right) => right.compareTo(left));

    int? systolic;
    int? diastolic;
    int? pulse;

    if (pressureCandidates.isNotEmpty) {
      systolic = pressureCandidates.firstWhere(
        (value) => value >= 50 && value <= 260,
        orElse: () => pressureCandidates.first,
      );
    }

    if (pressureCandidates.length > 1) {
      diastolic = pressureCandidates.firstWhere(
        (value) => value != systolic && value >= 30 && value <= 180,
        orElse: () => pressureCandidates[1],
      );
    }

    if (pulseCandidates.isNotEmpty) {
      pulse = pulseCandidates.firstWhere(
        (value) => value != systolic && value != diastolic,
        orElse: () => pulseCandidates.first,
      );
    }

    return _FallbackMetricParser(
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
    );
  }

  final int? systolic;
  final int? diastolic;
  final int? pulse;
}
