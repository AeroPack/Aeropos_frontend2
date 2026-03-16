import 'package:flutter/material.dart';

class SyncProgressDialog extends StatefulWidget {
  final dynamic syncService;
  final dynamic pendingDetails;
  final VoidCallback onSyncComplete;
  final VoidCallback onForceLogout;

  const SyncProgressDialog({
    super.key,
    required this.syncService,
    required this.pendingDetails,
    required this.onSyncComplete,
    required this.onForceLogout,
  });

  @override
  State<SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<SyncProgressDialog> {
  bool _isSyncing = true;
  bool _hasError = false;
  String _errorMessage = '';
  dynamic _syncResult;
  bool _showForceLogoutWarning = false;

  @override
  void initState() {
    super.initState();
    _performSync();
  }

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
      _hasError = false;
      _errorMessage = '';
      _syncResult = null;
      _showForceLogoutWarning = false;
    });

    try {
      final result = await widget.syncService.push();
      _syncResult = result;

      if (mounted) {
        if (result.success) {
          widget.onSyncComplete();
        } else {
          setState(() {
            _isSyncing = false;
            _hasError = true;
            _errorMessage = _buildErrorMessage(result);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hasError = true;
          _errorMessage = 'Failed to sync. Please check your connection.';
        });
      }
    }
  }

  String _buildErrorMessage(dynamic result) {
    final failedItems = <String>[];
    result.failedCounts.forEach((key, count) {
      if (count > 0) failedItems.add('$count $key');
    });
    return 'Failed to sync: ${failedItems.join(', ')}';
  }

  String _buildPendingMessage() {
    final pending = widget.pendingDetails;
    final items = <String>[];
    if (pending.categories > 0) items.add('${pending.categories} categories');
    if (pending.units > 0) items.add('${pending.units} units');
    if (pending.brands > 0) items.add('${pending.brands} brands');
    if (pending.products > 0) items.add('${pending.products} products');
    if (pending.customers > 0) items.add('${pending.customers} customers');
    if (pending.suppliers > 0) items.add('${pending.suppliers} suppliers');
    if (pending.employees > 0) items.add('${pending.employees} employees');
    if (pending.invoices > 0) items.add('${pending.invoices} invoices');
    return items.join(', ');
  }

  void _handleForceLogout() {
    if (_showForceLogoutWarning) {
      widget.onForceLogout();
    } else {
      setState(() => _showForceLogoutWarning = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _showForceLogoutWarning
            ? '⚠️ Warning: Data Loss'
            : (_hasError ? 'Sync Failed' : 'Syncing Changes'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isSyncing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Syncing ${_buildPendingMessage()}...'),
            const SizedBox(height: 8),
            const Text(
              'Please wait while we sync your changes to the server.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ] else if (_showForceLogoutWarning) ...[
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'You have unsaved changes that failed to sync. If you force logout now, these changes will be permanently lost.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_syncResult != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Failed Items:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildErrorMessage(_syncResult),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (_hasError) ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (_syncResult != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_syncResult.totalSynced > 0) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Synced: ${_syncResult.totalSynced} items',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (_syncResult.totalFailed > 0) ...[
                      Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Failed: ${_syncResult.totalFailed} items',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
      actions: [
        if (_hasError && !_showForceLogoutWarning) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(onPressed: _performSync, child: const Text('Retry')),
          TextButton(
            onPressed: _handleForceLogout,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Force Logout'),
          ),
        ] else if (_showForceLogoutWarning) ...[
          TextButton(
            onPressed: () => setState(() => _showForceLogoutWarning = false),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: _handleForceLogout,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Force Logout'),
          ),
        ],
      ],
    );
  }
}
