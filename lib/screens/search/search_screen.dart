import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/media/folder_card.dart';
import '../../widgets/media/video_list_tile.dart';
import '../dialogs/video_options_sheet.dart';

/// Full-screen search: recent searches, folder matches and video results.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play(VideoItem video, List<VideoItem> queue) {
    context.read<LibraryProvider>().addRecentSearch(_query);
    context.read<PlayerProvider>().open(video, queue: queue);
    Navigator.of(context).pushNamed(
      Routes.player,
      arguments: PlayerScreenArgs(video: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final query = _query.trim();
    final results = query.isEmpty
        ? <VideoItem>[]
        : library.search(query);
    final folderMatches = query.isEmpty
        ? <String>[]
        : library.folders
            .where((f) => f.name
                .toLowerCase()
                .contains(query.toLowerCase()))
            .map((f) => f.path)
            .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Search header -------------------------------------------
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.containerPadding,
                  20,
                  AppSpacing.containerPadding,
                  12),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Container(
                      height: 56,
                      padding: EdgeInsets.symmetric(
                          horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: AppRadius.pill,
                        border: Border.all(
                            color:
                                Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              color: AppColors.onSurfaceVariant),
                          SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              style: AppTypography.headlineMd
                                  .copyWith(fontSize: 20),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                                hintText:
                                    'Search videos, folders…',
                                hintStyle: AppTypography
                                    .headlineMd
                                    .copyWith(
                                  fontSize: 20,
                                  color: AppColors
                                      .onSurfaceVariant
                                      .withOpacity(0.5),
                                ),
                              ),
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  library.addRecentSearch(
                                      value.trim());
                                }
                              },
                            ),
                          ),
                          if (_query.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              tooltip: 'Clear',
                              icon: Icon(Icons.close,
                                  color:
                                      AppColors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --- Body ------------------------------------------------------
            Expanded(
              child: query.isEmpty
                  ? _RecentSearches(
                      searches: library.recentSearches,
                      onSelect: (term) {
                        _controller.text = term;
                        _controller.selection =
                            TextSelection.collapsed(
                                offset: term.length);
                        setState(() => _query = term);
                      },
                      onRemove: library.removeRecentSearch,
                      onClearAll: library.clearRecentSearches,
                    )
                  : (results.isEmpty && folderMatches.isEmpty)
                      ? EmptyState(
                          icon: Icons.search_off,
                          title: 'No results for “$query”',
                          message:
                              'Check the spelling or try a shorter keyword. '
                              'You can also rescan storage to pick up new files.',
                        )
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                              AppSpacing.containerPadding,
                              8,
                              AppSpacing.containerPadding,
                              48),
                          children: [
                            if (folderMatches.isNotEmpty) ...[
                              MicroHeader('FOLDERS'),
                              SizedBox(height: 12),
                              SizedBox(
                                height: 148,
                                child: ListView.separated(
                                  scrollDirection:
                                      Axis.horizontal,
                                  itemCount:
                                      folderMatches.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(width: 16),
                                  itemBuilder:
                                      (context, index) {
                                    final path =
                                        folderMatches[index];
                                    final folder = library
                                        .folders
                                        .firstWhere((f) =>
                                            f.path == path);
                                    return SizedBox(
                                      width: 240,
                                      child: FolderCard(
                                        name: folder.name,
                                        subtitle:
                                            '${folder.videoCount} ${folder.videoCount == 1 ? 'video' : 'videos'} • ${Formatters.bytes(folder.totalBytes)}',
                                        onTap: () {
                                          library
                                              .addRecentSearch(
                                                  query);
                                          Navigator.of(context)
                                              .pushNamed(
                                            Routes.folderVideos,
                                            arguments:
                                                folder.path,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: 28),
                            ],
                            MicroHeader(
                                'VIDEOS (${results.length})'),
                            SizedBox(height: 12),
                            for (final video in results)
                              Padding(
                                padding: EdgeInsets.only(
                                    bottom: 12),
                                child: VideoListTile(
                                  video: video,
                                  onTap: () =>
                                      _play(video, results),
                                  onMore: () =>
                                      showVideoOptionsSheet(
                                          context,
                                          video: video),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  _RecentSearches({
    required this.searches,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<String> searches;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return EmptyState(
        icon: Icons.manage_search,
        title: 'Search your library',
        message:
            'Find videos by name, folder or format. Your recent searches will appear here.',
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.containerPadding,
          8,
          AppSpacing.containerPadding,
          48),
      children: [
        Row(
          children: [
            Expanded(
                child: MicroHeader('RECENT SEARCHES')),
            TextButton(
              onPressed: onClearAll,
              child: Text(
                'Clear all',
                style: AppTypography.labelLg
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final term in searches)
              Material(
                color: AppColors.surfaceContainerHigh,
                shape: StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onSelect(term),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        16, 10, 10, 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 18,
                            color: AppColors.onSurfaceVariant),
                        SizedBox(width: 10),
                        Text(term,
                            style: AppTypography.labelLg),
                        SizedBox(width: 8),
                        InkWell(
                          onTap: () => onRemove(term),
                          customBorder: CircleBorder(),
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close,
                                size: 16,
                                color: AppColors
                                    .onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
