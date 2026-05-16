import 'package:flutter/material.dart';
import '../../../models/semester.dart';
import '../../../models/catalogue_course.dart';
import '../../../theme.dart';

// ── Semester tile ─────────────────────────────────────────────────────────────

class SemesterTile extends StatelessWidget {
  const SemesterTile({
    super.key,
    required this.semester,
    required this.courses,
    required this.onSetActive,
    required this.onEdit,
    required this.onDelete,
    required this.onAddCourse,
    required this.onEditCourse,
    required this.onDeleteCourse,
  });

  final Semester                    semester;
  final List<CatalogueCourse>       courses;
  final VoidCallback                onSetActive;
  final VoidCallback                onEdit;
  final VoidCallback                onDelete;
  final VoidCallback                onAddCourse;
  final ValueChanged<CatalogueCourse> onEditCourse;
  final ValueChanged<CatalogueCourse> onDeleteCourse;

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isActive = semester.isActive;

    return Card(
      margin:    const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isActive ? cs.primary : cs.outlineVariant,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: isActive,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs,
        ),
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(child: _titleColumn(context, cs)),
            _activeBadge(cs),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit semester',
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
              tooltip: 'Delete semester',
              onPressed: onDelete,
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          if (courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.lg,
              ),
              child: Text(
                'No courses yet. Add one below.',
                style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
              ),
            ),
          ...courses.map(
            (c) => CourseTile(
              // KEY: prevents data/render state from bleeding across rows after add/delete.
              key:      ValueKey(c.id),
              course:   c,
              onEdit:   () => onEditCourse(c),
              onDelete: () => onDeleteCourse(c),
            ),
          ),
          _addCourseRow(cs),
        ],
      ),
    );
  }

  Widget _titleColumn(BuildContext context, ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(semester.label, style: context.textStyles.titleMedium?.semiBold),
      if (courses.isNotEmpty)
        Text(
          '${courses.length} course${courses.length > 1 ? 's' : ''}',
          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
        ),
    ],
  );

  Widget _activeBadge(ColorScheme cs) => GestureDetector(
    onTap: onSetActive,
    child: AnimatedContainer(
      duration:  const Duration(milliseconds: 200),
      padding:   const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: semester.isActive
            ? cs.primary.withValues(alpha: 0.12)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: semester.isActive ? cs.primary : cs.outlineVariant,
        ),
      ),
      child: Text(
        semester.isActive ? '● Active' : 'Set Active',
        style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color: semester.isActive ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    ),
  );

  Widget _addCourseRow(ColorScheme cs) => InkWell(
    onTap: onAddCourse,
    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.md)),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline, size: 18, color: cs.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Add Course',
            style: TextStyle(
              color:      cs.primary,
              fontWeight: FontWeight.w600,
              fontSize:   14,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Course tile ───────────────────────────────────────────────────────────────

class CourseTile extends StatelessWidget {
  const CourseTile({
    super.key,
    required this.course,
    required this.onEdit,
    required this.onDelete,
  });

  final CatalogueCourse course;
  final VoidCallback    onEdit;
  final VoidCallback    onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        ListTile(
          dense:          true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 0,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  course.name,
                  style: context.textStyles.bodyMedium?.semiBold,
                ),
              ),
              Container(
                padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  course.code,
                  style: TextStyle(
                    fontSize:      11,
                    fontWeight:    FontWeight.w700,
                    color:         cs.onPrimaryContainer,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          subtitle: (course.department != null || course.credits != null)
              ? Text(
                  [
                    if (course.department != null) course.department!,
                    if (course.credits != null) '${course.credits} credits',
                  ].join('  ·  '),
                  style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon:     const Icon(Icons.edit_outlined, size: 16),
                tooltip:  'Edit',
                onPressed: onEdit,
              ),
              IconButton(
                icon:     Icon(Icons.delete_outline, size: 16, color: cs.error),
                tooltip:  'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          indent: AppSpacing.md,
          color:  cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}
