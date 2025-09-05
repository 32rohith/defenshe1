import 'package:flutter/material.dart';
import 'package:sih_1/pages/dashboard/report_issue.dart';

class ReportButton extends StatelessWidget {
  const ReportButton({super.key});

  void _showReportIssueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => ReportIssueDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        onPressed: () => _showReportIssueDialog(context),
        iconSize: 30,
        icon: const Icon(Icons.report_outlined),
      ),
    );
  }
}