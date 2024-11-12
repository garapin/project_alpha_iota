import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interacting_tom/features/presentation/text_to_speech_cloud.dart';
import 'package:interacting_tom/features/presentation/text_to_speech_local.dart';
import 'package:interacting_tom/features/providers/openai_response_controller.dart';
import 'package:interacting_tom/features/providers/animation_state_controller.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:collection/collection.dart';

class STTWidget extends ConsumerStatefulWidget {
  const STTWidget({super.key});

  @override
  ConsumerState<STTWidget> createState() => _STTWidgetState();
}

class _STTWidgetState extends ConsumerState<STTWidget> {
  final SpeechToText _speechToText = SpeechToText();
  String _lastWords = '';
  List<LocaleName> _localeNames = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void errorListener(SpeechRecognitionError error) {
    print(
        'Received error status: $error, listening: ${_speechToText.isListening}');
    ref.read(animationStateControllerProvider.notifier).updateHearing(false);
  }

  void statusListener(String status) {
    if (status == 'done') {
      ref.read(animationStateControllerProvider.notifier).updateHearing(false);
    }
    print(
        'Received listener status: $status, listening: ${_speechToText.isListening}');
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    await _speechToText.initialize(
        onError: errorListener, onStatus: statusListener);
    _localeNames = await _speechToText.locales();
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    if (_speechToText.isListening) {
      print('Already listening');
      return;
    }
    ref.read(animationStateControllerProvider.notifier).updateHearing(true);
    final localeId = _getCurrentLocale();
    await _speechToText.listen(onResult: _onSpeechResult, localeId: localeId);

    setState(() {});
  }

  String _getCurrentLocale() {
    final String currentLang =
        ref.read(animationStateControllerProvider).language;

    final locale = _localeNames.firstWhereOrNull(
        (locale) => locale.localeId.contains(currentLang.toUpperCase()));
    if (locale == null || _localeNames.isEmpty) {
      return currentLang == 'en' ? 'en-US' : 'ja-JP';
    } else {
      return locale.localeId;
    }
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    ref.read(animationStateControllerProvider.notifier).updateHearing(false);
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) async {
    if (result.finalResult) {
      _lastWords = result.recognizedWords;
      ref
          .read(openAIResponseControllerProvider.notifier)
          .getResponse(_lastWords);
      _stopListening();
      // setState(() {
      //   _lastWords = result.recognizedWords;

      //   print('Last words: $_lastWords');
      //   print('Confidence: ${result.confidence}');
      // });
    }
  }

  bool get _isListening => _speechToText.isListening;

  @override
  Widget build(BuildContext context) {
    print('Built STT widget');
    print("IS LISTENING: $_isListening");

    final micIcon =
        _isListening ? const Icon(Icons.mic) : const Icon(Icons.mic_off);
    //final child = TextToSpeechCloud(child: micIcon);
    final child = TextToSpeechLocal(child: micIcon);
    return FloatingActionButton(
        onPressed: () {
          print("IS LISTENING: $_isListening");
          _isListening ? _stopListening() : _startListening();
        },
        tooltip: _isListening ? 'Pause' : 'Play',
        child: child);
  }
}
