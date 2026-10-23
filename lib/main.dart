import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

// NOTE: verify this filename on the Hugging Face repo's "Files" tab.
// If the repo is gated, accept the license and pass a token with
//   --dart-define=HUGGINGFACE_TOKEN=hf_xxx
const _modelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const hfToken = String.fromEnvironment('HUGGINGFACE_TOKEN');
  await FlutterEdgeAi.initialize(
    inferenceEngines: const [LiteRtLmEngine()],
    huggingFaceToken: hfToken.isEmpty ? null : hfToken,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gemma Chat',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const ChatPage(),
      );
}

class ChatMessage {
  ChatMessage({required this.text, required this.isUser});
  String text;
  final bool isUser;
}

enum Phase { checking, needsDownload, downloading, loading, ready, error }

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];

  Phase _phase = Phase.checking;
  int _progress = 0;
  String? _error;
  bool _generating = false;

  InferenceModel? _model;
  InferenceChat? _chat;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _model?.close();
    super.dispose();
  }

  // Tries to load an already-installed model; otherwise asks to download.
  Future<void> _loadModel() async {
    setState(() => _phase = Phase.loading);
    try {
      // maxTokens is the whole context window (prompt + history + reply).
      _model = await FlutterEdgeAi.getActiveModel(maxTokens: 2048);
      _chat = await _model!.createChat();
      setState(() => _phase = Phase.ready);
    } on StateError {
      // NoActiveModelError is a StateError: nothing installed yet.
      setState(() => _phase = Phase.needsDownload);
    } catch (e) {
      setState(() {
        _phase = Phase.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _phase = Phase.downloading;
      _progress = 0;
    });
    try {
      await FlutterEdgeAi.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm, // selects the engine
      )
          .fromNetwork(_modelUrl)
          .withProgress((p) {
            if (mounted) setState(() => _progress = p.toInt());
          })
          .install();
      await _loadModel();
    } catch (e) {
      setState(() {
        _phase = Phase.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _generating || _chat == null) return;
    _controller.clear();

    final reply = ChatMessage(text: '', isUser: false);
    setState(() {
      _messages
        ..add(ChatMessage(text: text, isUser: true))
        ..add(reply);
      _generating = true;
    });
    _scrollToBottom();

    try {
      // isUser: true is required, otherwise the model returns an empty answer.
      await _chat!.addQueryChunk(Message.text(text: text, isUser: true));
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          setState(() => reply.text += response.token);
          _scrollToBottom();
        }
      }
    } catch (e) {
      setState(() => reply.text =
          reply.text.isEmpty ? 'Error: $e' : '${reply.text}\n\n[Error: $e]');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _newChat() async {
    if (_model == null || _generating) return;
    final chat = await _model!.createChat();
    setState(() {
      _chat = chat;
      _messages.clear();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemma 4 (on-device)'),
        actions: [
          if (_phase == Phase.ready)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: _newChat,
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case Phase.checking:
      case Phase.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading model…'),
            ],
          ),
        );
      case Phase.needsDownload:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Gemma 4 E2B needs a one-time download (~2.4 GB).\n'
                  'Use Wi-Fi. After this the app works fully offline.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _downloadModel,
                  icon: const Icon(Icons.download),
                  label: const Text('Download model'),
                ),
              ],
            ),
          ),
        );
      case Phase.downloading:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: _progress / 100),
                const SizedBox(height: 12),
                Text('Downloading… $_progress%'),
              ],
            ),
          ),
        );
      case Phase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _loadModel,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case Phase.ready:
        return _buildChat();
    }
  }

  Widget _buildChat() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(child: Text('Say hi to Gemma 👋'))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isLastAndEmpty =
                        !m.isUser && m.text.isEmpty && _generating;
                    return Align(
                      alignment: m.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        decoration: BoxDecoration(
                          color: m.isUser
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: isLastAndEmpty
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : SelectableText(m.text),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _generating ? null : _send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
