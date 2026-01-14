import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/alexa_oauth_service.dart';

class SocialSettingsScreen extends StatefulWidget {
  const SocialSettingsScreen({super.key});

  @override
  State<SocialSettingsScreen> createState() => _SocialSettingsScreenState();
}

class _SocialSettingsScreenState extends State<SocialSettingsScreen> {
  final _alexaCodeController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;

  // Alexa Reminder (LWA OAuth) state
  bool _alexaReminderConnected = false;
  bool _isConnectingAlexa = false;
  String? _alexaLinkCode;
  bool _isGeneratingCode = false;
  
  // OAuth callback subscription
  StreamSubscription<bool>? _oauthSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupOAuthListener();
  }

  @override
  void dispose() {
    _alexaCodeController.dispose();
    _oauthSubscription?.cancel();
    super.dispose();
  }
  
  void _setupOAuthListener() {
    // Listen for OAuth completion events
    _oauthSubscription = AlexaOAuthService().onOAuthComplete.listen((success) {
      if (mounted) {
        if (success) {
          setState(() => _alexaReminderConnected = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alexa Reminders connected successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect Alexa Reminders'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isConnectingAlexa = false);
      }
    });
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        _userId = user.id;
        final settings = await ApiService.getAlexaSettings(user.id);
        _alexaCodeController.text = settings['alexaAccessCode'] ?? '';

        // Load Alexa Reminder settings
        try {
          final reminderSettings = await ApiService.getAlexaReminderSettings(user.id);
          _alexaReminderConnected = reminderSettings['accessToken'] != null &&
              (reminderSettings['accessToken'] as String).isNotEmpty;
        } catch (e) {
          // Settings might not exist yet, that's okay
          _alexaReminderConnected = false;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAlexaSettings() async {
    if (_userId == null) return;

    setState(() => _isSaving = true);
    try {
      await ApiService.setAlexaSettings(_userId!, _alexaCodeController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alexa settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _generateAlexaLinkCode() async {
    if (_userId == null) return;

    setState(() => _isGeneratingCode = true);
    try {
      final code = await ApiService.generateAlexaLinkCode(_userId!);
      if (mounted) {
        setState(() => _alexaLinkCode = code);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate code: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isGeneratingCode = false);
    }
  }

  /// Launches the Login with Amazon OAuth flow for Alexa Reminders
  Future<void> _connectAlexaReminder() async {
    if (_userId == null) return;
    
    setState(() => _isConnectingAlexa = true);

    const clientId = 'amzn1.application-oa2-client.2f4b358af3fd4d298e64ee2f45806b96';
    const redirectUri = 'https://app.rythmn.online/alexa-callback.html';
    const scope = 'alexa::alerts:reminders:skill:readwrite';

    // Set the pending user ID for the OAuth callback
    AlexaOAuthService().setPendingUserId(_userId!);
    
    // Store user ID in localStorage for the web callback page
    _storeUserIdForOAuth(_userId!);

    // Use state parameter to pass user ID securely
    final state = _userId!;

    final authUrl = Uri.parse(
      'https://www.amazon.com/ap/oa?client_id=$clientId'
      '&scope=$scope'
      '&response_type=code'
      '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
      '&state=${Uri.encodeComponent(state)}',
    );

    try {
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
        // The callback will be handled by the OAuth listener set up in initState

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete the authorization in your browser, then return to the app'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        throw Exception('Could not launch Amazon login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isConnectingAlexa = false);
    }
  }

  Future<void> _disconnectAlexaReminder() async {
    if (_userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Alexa Reminders?'),
        content: const Text(
          'You will no longer receive Alexa reminders for your habits. You can reconnect anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isConnectingAlexa = true);
    try {
      await ApiService.deleteAlexaReminderSettings(_userId!);
      setState(() => _alexaReminderConnected = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alexa Reminders disconnected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isConnectingAlexa = false);
    }
  }

  /// Store user ID in localStorage for the web callback page
  void _storeUserIdForOAuth(String userId) {
    try {
      html.window.localStorage['alexa_oauth_user_id'] = userId;
    } catch (e) {
      debugPrint('Failed to store user ID in localStorage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social & Integrations'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAlexaSection(),
                const SizedBox(height: 16),
                _buildAlexaReminderSection(),
              ],
            ),
    );
  }

  Widget _buildAlexaSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.speaker,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Amazon Alexa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Get task reminders on your Alexa device',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Setup Instructions:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildInstructionStep('1', 'Enable the "Notify Me" skill on your Alexa'),
            _buildInstructionStep('2', 'Say "Alexa, open Notify Me" to get your access code'),
            _buildInstructionStep('3', 'Enter the access code below'),
            const SizedBox(height: 16),
            TextField(
              controller: _alexaCodeController,
              decoration: const InputDecoration(
                labelText: 'Notify Me Access Code',
                hintText: 'Enter your access code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAlexaSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlexaReminderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.alarm,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Alexa Reminders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _alexaReminderConnected
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _alexaReminderConnected ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _alexaReminderConnected ? Icons.check_circle : Icons.warning_amber,
                        size: 16,
                        color: _alexaReminderConnected ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _alexaReminderConnected ? 'Connected' : 'Not Connected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _alexaReminderConnected ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Get actual Alexa reminders (with alarm) for your habits',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),

            // Setup instructions
            if (!_alexaReminderConnected) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to connect:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _buildInstructionStep('1', 'Generate a link code below'),
                    _buildInstructionStep('2', 'Say "Alexa, open my rythmn"'),
                    _buildInstructionStep('3', 'Say "my code is" followed by your 6-digit code'),
                    _buildInstructionStep('4', 'Once linked, say "sync my habits" to create reminders'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Generate Code section
              if (_alexaLinkCode != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00CAFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00CAFF), width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Link Code',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _alexaLinkCode!,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tell Alexa: "my code is ${_alexaLinkCode!}"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code expires in 10 minutes',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Generate Code button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingCode ? null : _generateAlexaLinkCode,
                  icon: _isGeneratingCode
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.vpn_key),
                  label: Text(_alexaLinkCode == null ? 'Generate Link Code' : 'Generate New Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00CAFF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Open Alexa App button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Open Alexa app dev skills section
                  final url = Uri.parse('https://alexa.amazon.com/spa/index.html#skills/your-skills/?ref-suffix=ysa_gw&skillTypes=all');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Alexa App → Your Skills → Dev'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00CAFF), // Alexa blue
                  foregroundColor: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Voice command hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00CAFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00CAFF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over, color: Color(0xFF00CAFF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Voice Command',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"Alexa, ask my rythmn to sync my habits"',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Info note
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reminders are created when you ask Alexa to sync',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
