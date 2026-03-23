import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../di/service_locator.dart';
import 'sync_progress_dialog.dart';
import 'pos_calculator.dart';
import 'company_switcher.dart';

class MasterHeader extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback? onSidebarToggle;
  final bool showSidebarToggle;
  final bool isDesktop;
  final List<Widget>? actions;
  final List<Widget>? customActions;
  final bool hidePosButton;
  final Widget? title;
  final Widget? leading;
  final double? leadingWidth;
  final String? searchQuery;
  final ValueChanged<String>? onSearch;

  const MasterHeader({
    super.key,
    this.onSidebarToggle,
    this.showSidebarToggle = true,
    this.isDesktop = true,
    this.actions,
    this.customActions,
    this.hidePosButton = false,
    this.title,
    this.leading,
    this.leadingWidth,
    this.searchQuery,
    this.onSearch,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isLargeDesktop = width > 1200;
    final isMediumDesktop = width > 1000;
    final isSmallDesktop = width > 900;
    final isTablet = width > 600;
    final isActuallyDesktop = isSmallDesktop;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      shape: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      leadingWidth:
          leadingWidth ??
          (isActuallyDesktop ? (isLargeDesktop ? 250 : 200) : null),
      leading:
          leading ??
          (isActuallyDesktop
              ? InkWell(
                  onTap: () => context.go('/dashboard'),
                  mouseCursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront,
                          color: Color(0xFF0F172A),
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Aero",
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "POS",
                          style: TextStyle(
                            color: Color.fromARGB(255, 0, 191, 255),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null),
      title:
          title ??
          Row(
            children: [
              if (isActuallyDesktop && showSidebarToggle) ...[
                IconButton(
                  onPressed: onSidebarToggle,
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.compare_arrows,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Container(
                  height: 40,
                  constraints: BoxConstraints(
                    maxWidth: isLargeDesktop
                        ? 400
                        : (isMediumDesktop ? 300 : 250),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextField(
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      hintText: "Search",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 10,
                      ),
                      suffixIcon: isTablet
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                              child: Container(
                                width: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "⌘ K",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
      actions:
          actions ??
          [
            ...?customActions,
            if (isSmallDesktop) ...[
              const CompanySwitcher(),
              const SizedBox(width: 8),
            ],
            if (isMediumDesktop) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/new-invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text("Add New"),
                ),
              ),
              if (!hidePosButton)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/pos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.monitor, size: 18),
                    label: const Text("POS"),
                  ),
                ),
            ],
            if (isTablet)
              IconButton(
                onPressed: () => _toggleFullscreen(context),
                icon: const Icon(Icons.fullscreen, color: Colors.grey),
                tooltip: 'Toggle Fullscreen',
              ),
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.1),
                  builder: (ctx) => Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    alignment: Alignment.topRight,
                    insetPadding: const EdgeInsets.only(top: 70, right: 16),
                    child: PosCalculator(onClose: () => Navigator.pop(ctx)),
                  ),
                );
              },
              icon: const Icon(Icons.calculate_outlined, color: Colors.grey),
              tooltip: 'Calculator',
            ),
            if (isTablet)
              IconButton(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined, color: Colors.grey),
                tooltip: 'Settings',
              ),
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 8),
              child: PopupMenuButton<String>(
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: const NetworkImage(
                    'https://i.pravatar.cc/150?img=11',
                  ),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'profile':
                      context.push('/profile');
                      break;
                    case 'company':
                      context.push('/company-profile');
                      break;
                    case 'manage_companies':
                      context.push('/my-companies');
                      break;
                    case 'settings':
                      context.push('/settings');
                      break;
                    case 'logout':
                      _handleLogout(context, ref);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person_outline, size: 20),
                      title: Text(
                        'User Profile',
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'company',
                    child: ListTile(
                      leading: Icon(Icons.business_outlined, size: 20),
                      title: Text(
                        'Company Profile',
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'manage_companies',
                    child: ListTile(
                      leading: Icon(Icons.business_rounded, size: 20),
                      title: Text(
                        'Manage Companies',
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined, size: 20),
                      title: Text('Settings', style: TextStyle(fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, size: 20, color: Colors.red),
                      title: Text(
                        'Logout',
                        style: TextStyle(fontSize: 14, color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
    );
  }

  void _toggleFullscreen(BuildContext context) {
    final isFullscreen =
        MediaQuery.of(context).viewInsets.top > 0 ||
        MediaQuery.of(context).size.width == MediaQuery.of(context).size.width;

    if (isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final syncService = ServiceLocator.instance.syncService;
    final pendingDetails = await syncService.getPendingChangesDetails();

    if (pendingDetails.hasPending) {
      if (!context.mounted) return;
      await _showSyncDialog(context, ref, syncService, pendingDetails);
    } else {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  Future<void> _showSyncDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic syncService,
    dynamic pendingDetails,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return SyncProgressDialog(
          syncService: syncService,
          pendingDetails: pendingDetails,
          onSyncComplete: () async {
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            await ref.read(authControllerProvider.notifier).logout();
          },
          onForceLogout: () async {
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            await ref.read(authControllerProvider.notifier).logout();
          },
        );
      },
    );
  }
}
