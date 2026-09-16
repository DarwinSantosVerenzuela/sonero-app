import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';

/// 10-band frequency labels (Hz).
const List<String> kEqBandLabels = [
  '32', '64', '125', '250', '500', '1k', '2k', '4k', '8k', '16k',
];

/// Channel output mode.
enum ChannelMode { stereo, mono, extraStereo }

/// Named EQ presets.
enum EqPreset {
  flat,
  rock,
  pop,
  jazz,
  classical,
  electronic,
  bassBoost,
  vocal,
  acoustic,
  custom,
}

extension EqPresetLabel on EqPreset {
  String get label => switch (this) {
    EqPreset.flat        => 'Flat',
    EqPreset.rock        => 'Rock',
    EqPreset.pop         => 'Pop',
    EqPreset.jazz        => 'Jazz',
    EqPreset.classical   => 'Clásica',
    EqPreset.electronic  => 'Electrónica',
    EqPreset.bassBoost   => 'Bass Boost',
    EqPreset.vocal       => 'Vocal',
    EqPreset.acoustic    => 'Acústico',
    EqPreset.custom      => 'Personalizado',
  };
}

/// Predefined band gain values (dB, range –12 … +12).
/// Tuned aggressively so the difference is immediately noticeable,
/// even on cheap earbuds.
const Map<EqPreset, List<double>> kPresetValues = {
  EqPreset.flat:       [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0],
  EqPreset.rock:       [ 8,  6,  4,  2, -2,  2,  5,  7,  9, 10],
  EqPreset.pop:        [-2,  2,  5,  7,  5,  1, -1,  0,  3,  5],
  EqPreset.jazz:       [ 6,  5,  2,  3, -2, -1,  1,  3,  6,  8],
  EqPreset.classical:  [ 8,  7,  5,  3, -2, -2,  1,  4,  6,  8],
  EqPreset.electronic: [10,  8,  3,  0, -3,  3,  2,  6,  9, 11],
  EqPreset.bassBoost:  [12, 10,  8,  5,  2,  0,  0,  0,  0,  0],
  EqPreset.vocal:      [-4, -3,  0,  4,  8,  8,  6,  2,  0, -2],
  EqPreset.acoustic:   [ 7,  5,  3,  1, -2,  1,  3,  5,  7,  6],
};

class EqualizerProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _enabled = false;
  bool get enabled => _enabled;

  EqPreset _preset = EqPreset.flat;
  EqPreset get preset => _preset;

  /// 10 band gains in dB (–12 … +12).
  List<double> _bands = List.filled(10, 0.0);
  List<double> get bands => List.unmodifiable(_bands);

  // Bass boost
  bool _bassBoostEnabled = false;
  bool get bassBoostEnabled => _bassBoostEnabled;

  double _bassBoostGain = 12.0; // dB — starts punchy
  double get bassBoostGain => _bassBoostGain;

  // Channel mode
  ChannelMode _channelMode = ChannelMode.stereo;
  ChannelMode get channelMode => _channelMode;

  double _extraStereoMultiplier = 3.0;
  double get extraStereoMultiplier => _extraStereoMultiplier;

  // Loudness normalization
  bool _loudnessEnabled = false;
  bool get loudnessEnabled => _loudnessEnabled;

  // Balance L/R  (–1.0 = full left, 0 = centre, +1.0 = full right)
  double _balance = 0.0;
  double get balance => _balance;

  // Reference to the Player instance – set once from PlayerProvider.
  Player? _player;

  // ── Init ───────────────────────────────────────────────────────────────────

  EqualizerProvider() {
    _loadFromPrefs();
  }

  void setPlayer(Player player) {
    _player = player;
    // Apply current state immediately.
    _applyFilters();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  void toggle() {
    _enabled = !_enabled;
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void setEnabled(bool value) {
    _enabled = value;
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void setPreset(EqPreset preset) {
    _preset = preset;
    if (preset != EqPreset.custom) {
      _bands = List<double>.from(kPresetValues[preset]!);
    }
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void setBand(int index, double gainDb) {
    if (index < 0 || index >= 10) return;
    _bands[index] = gainDb.clamp(-12.0, 12.0);
    _preset = EqPreset.custom;
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void setBassBoostEnabled(bool value) {
    _bassBoostEnabled = value;
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void setBassBoostGain(double gain) {
    _bassBoostGain = gain.clamp(0.0, 30.0);
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void setChannelMode(ChannelMode mode) {
    _channelMode = mode;
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void setExtraStereoMultiplier(double m) {
    _extraStereoMultiplier = m.clamp(1.0, 4.0);
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void setLoudnessEnabled(bool value) {
    _loudnessEnabled = value;
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void setBalance(double value) {
    _balance = value.clamp(-1.0, 1.0);
    _applyFilters();
    _persist();
    notifyListeners();
  }

  void reset() {
    _preset = EqPreset.flat;
    _bands = List.filled(10, 0.0);
    _bassBoostEnabled = false;
    _bassBoostGain = 12.0;
    _channelMode = ChannelMode.stereo;
    _extraStereoMultiplier = 3.0;
    _loudnessEnabled = false;
    _balance = 0.0;
    _applyFilters();
    _persist();
    notifyListeners();
  }

  // ── MPV filter builder ─────────────────────────────────────────────────────

  void _applyFilters() {
    if (_player == null) return;

    if (!_enabled) {
      _setProperty('af', '');
      return;
    }

    final filters = <String>[];

    // 1. Superequalizer (18-band, we use the first 10)
    final hasEq = _bands.any((g) => g != 0.0);
    if (hasEq) {
      // MPV superequalizer maps: bands 1-18 at ~55Hz intervals.
      // We map our 10 bands roughly: 1→32,2→64,3→125,5→250,7→500,9→1k,11→2k,13→4k,15→8k,17→16k
      final sb = StringBuffer('superequalizer=');
      const mapping = [1, 2, 3, 5, 7, 9, 11, 13, 15, 17];
      for (int i = 0; i < 10; i++) {
        if (i > 0) sb.write(':');
        sb.write('${mapping[i]}b=${_bands[i].toStringAsFixed(1)}');
      }
      filters.add(sb.toString());
    }

    // 2. Bass boost — wider frequency range and steeper slope for PUNCH
    if (_bassBoostEnabled && _bassBoostGain > 0) {
      // Two-stage bass: sub-bass (60Hz) + mid-bass (120Hz) for full impact
      final subGain = (_bassBoostGain * 0.8).toStringAsFixed(1);
      final midGain = (_bassBoostGain * 0.5).toStringAsFixed(1);
      filters.add('bass=g=${_bassBoostGain.toStringAsFixed(1)}:f=80:w=0.7');
      filters.add('bass=g=$midGain:f=150:w=0.5');
    }

    // 3. Channel mode
    switch (_channelMode) {
      case ChannelMode.mono:
        filters.add('pan=1c|c0=0.5*c0+0.5*c1');
        break;
      case ChannelMode.extraStereo:
        filters.add('extrastereo=m=${_extraStereoMultiplier.toStringAsFixed(1)}');
        break;
      case ChannelMode.stereo:
        break; // default, no filter needed
    }

    // 4. Balance (pan)
    if (_balance != 0.0) {
      final left  = (1.0 - _balance.clamp(0.0, 1.0));
      final right = (1.0 + _balance.clamp(-1.0, 0.0));
      filters.add('pan=2c|c0=${left.toStringAsFixed(2)}*c0|c1=${right.toStringAsFixed(2)}*c1');
    }

    // 5. Loudness enhancement — aggressive normalization + dynamic compression
    if (_loudnessEnabled) {
      // EBU R128 normalization with louder target (-10 LUFS) + headroom
      filters.add('loudnorm=I=-10:TP=-1:LRA=7');
      // Dynamic range compression: makes quiet parts louder, loud parts controlled
      // This is what makes cheap earbuds sound "full" and powerful
      filters.add('acompressor=threshold=0.05:ratio=4:attack=5:release=100:makeup=6');
    }

    final chain = filters.join(',');
    debugPrint('[EQ] Setting af=$chain');
    _setProperty('af', chain);
  }

  void _setProperty(String name, String value) {
    if (_player == null) return;
    try {
      // media_kit Player exposes the underlying native player via .platform
      // On native (Windows/Android), this is NativePlayer which has setProperty
      if (!kIsWeb) {
        final platform = _player!.platform;
        // Use reflection-safe approach: call setProperty if available
        (platform as dynamic).setProperty(name, value);
      }
    } catch (e) {
      debugPrint('[EQ] Error setting property $name: $e');
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('eq_enabled', _enabled);
      prefs.setInt('eq_preset', _preset.index);
      prefs.setStringList('eq_bands', _bands.map((b) => b.toString()).toList());
      prefs.setBool('eq_bass_enabled', _bassBoostEnabled);
      prefs.setDouble('eq_bass_gain', _bassBoostGain);
      prefs.setInt('eq_channel_mode', _channelMode.index);
      prefs.setDouble('eq_extra_stereo', _extraStereoMultiplier);
      prefs.setBool('eq_loudness', _loudnessEnabled);
      prefs.setDouble('eq_balance', _balance);
    } catch (e) {
      debugPrint('[EQ] Error persisting: $e');
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('eq_enabled') ?? false;
      final presetIdx = prefs.getInt('eq_preset') ?? 0;
      _preset = EqPreset.values[presetIdx.clamp(0, EqPreset.values.length - 1)];
      final savedBands = prefs.getStringList('eq_bands');
      if (savedBands != null && savedBands.length == 10) {
        _bands = savedBands.map((s) => double.tryParse(s) ?? 0.0).toList();
      } else if (_preset != EqPreset.custom && kPresetValues.containsKey(_preset)) {
        _bands = List<double>.from(kPresetValues[_preset]!);
      }
      _bassBoostEnabled = prefs.getBool('eq_bass_enabled') ?? false;
      _bassBoostGain = prefs.getDouble('eq_bass_gain') ?? 8.0;
      final channelIdx = prefs.getInt('eq_channel_mode') ?? 0;
      _channelMode = ChannelMode.values[channelIdx.clamp(0, ChannelMode.values.length - 1)];
      _extraStereoMultiplier = prefs.getDouble('eq_extra_stereo') ?? 2.5;
      _loudnessEnabled = prefs.getBool('eq_loudness') ?? false;
      _balance = prefs.getDouble('eq_balance') ?? 0.0;
      notifyListeners();
    } catch (e) {
      debugPrint('[EQ] Error loading prefs: $e');
    }
  }
}
