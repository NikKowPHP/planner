import 'package:flutter/material.dart';
import '../../models/slash_command.dart';
import 'slash_menu_item.dart';

class SlashMenu extends StatefulWidget {
  final List<SlashCommand> commands;
  final int selectedIndex;
  final String query;
  final Function(SlashCommand) onCommandSelected;

  const SlashMenu({
    super.key,
    required this.commands,
    required this.selectedIndex,
    required this.query,
    required this.onCommandSelected,
  });

  @override
  State<SlashMenu> createState() => _SlashMenuState();
}

class _SlashMenuState extends State<SlashMenu> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(SlashMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _scrollToIndex(widget.selectedIndex);
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 56.0; // Approx height of SlashMenuItem
    final double targetOffset = index * itemHeight;
    final double viewportHeight = _scrollController.position.viewportDimension;
    final double currentOffset = _scrollController.offset;

    if (targetOffset < currentOffset) {
      _scrollController.jumpTo(targetOffset);
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _scrollController.jumpTo(targetOffset + itemHeight - viewportHeight);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5), 
            blurRadius: 30, 
            spreadRadius: 5
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                const Text("Blocks", style: TextStyle(color: Colors.white54, fontSize: 12)),
                const Spacer(),
                Text(
                  widget.query.isEmpty ? "Type to filter" : "'${widget.query}'", 
                  style: const TextStyle(color: Colors.white30, fontSize: 12)
                ),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: widget.commands.isEmpty 
              ? const Center(child: Text("No commands found", style: TextStyle(color: Colors.white38))) 
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(6),
                  itemCount: widget.commands.length,
                  itemBuilder: (context, index) {
                    return SlashMenuItem(
                      command: widget.commands[index],
                      isSelected: index == widget.selectedIndex,
                      onTap: () => widget.onCommandSelected(widget.commands[index]),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
