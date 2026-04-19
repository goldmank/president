import 'dart:async';

import 'package:flutter/material.dart';

import 'app_error.dart';
import 'error_report_api.dart';
import 'president_theme.dart';

Future<void> showAppErrorDialog(
  BuildContext context, {
  required String title,
  required Object error,
  required int fallbackCode,
  required String fallbackMessage,
  String? reportContext,
}) async {
  final info = describeAppError(
    error,
    fallbackCode: fallbackCode,
    fallbackMessage: fallbackMessage,
  );

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: presidentSurfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          title,
          style: const TextStyle(
            color: presidentText,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              info.message,
              style: const TextStyle(
                color: presidentMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'ERROR CODE: ${info.code}',
              style: TextStyle(
                color: presidentText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(
                ErrorReportApi.instance.sendReport(
                  title: title,
                  error: info,
                  reportContext: reportContext,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: presidentPrimary,
              foregroundColor: Colors.black,
            ),
            child: const Text('REPORT'),
          ),
        ],
      );
    },
  );
}
