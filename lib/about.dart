import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final Uri _authorUri = Uri.parse('https://www.qrz.com/db/SP7SMI');

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.aboutLinkOpenError),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final websiteUri = Uri.parse(l10n.aboutWebsiteValue);
    final privacyUri = Uri.parse(l10n.aboutPrivacyValue);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(
                l10n.aboutLead,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.aboutSecondary,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.surfaceVariant,
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    l10n.aboutDisclaimer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.aboutAuthorLabel),
                  subtitle: SelectableText(
                    l10n.aboutAuthorCredit,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  onTap: () => _launchUri(context, _authorUri),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.aboutWebsiteLabel),
                  subtitle: SelectableText(
                    l10n.aboutWebsiteValue,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  onTap: () => _launchUri(context, websiteUri),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.aboutPrivacyLabel),
                  subtitle: SelectableText(
                    l10n.aboutPrivacyValue,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  onTap: () => _launchUri(context, privacyUri),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
