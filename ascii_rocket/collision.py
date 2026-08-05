from __future__ import annotations

from .models import Entity, FontMetrics


def entity_bounds(entity: Entity, metrics: FontMetrics) -> tuple[float, float, float, float]:
    return (
        entity.x,
        entity.y,
        entity.x + entity.art.columns * metrics.cell_width,
        entity.y + entity.art.row_count * metrics.line_height,
    )


def rectangles_overlap(
    first: tuple[float, float, float, float], second: tuple[float, float, float, float]
) -> bool:
    return first[0] < second[2] and first[2] > second[0] and first[1] < second[3] and first[3] > second[1]


class CollisionSystem:
    @staticmethod
    def collides(
        first: Entity, second: Entity, metrics: FontMetrics, forgiveness: float = 0.0
    ) -> bool:
        if not rectangles_overlap(entity_bounds(first, metrics), entity_bounds(second, metrics)):
            return False
        forgiveness = max(0.0, min(0.4, forgiveness))
        inset_x = metrics.cell_width * forgiveness / 2.0
        inset_y = metrics.line_height * forgiveness / 2.0
        second_cells = {
            (column, row)
            for column, row in second.art.occupied
        }
        # Fast exact grid alignment path.
        if first.x == second.x and first.y == second.y:
            return bool(set(first.art.occupied) & second_cells)
        for first_column, first_row in first.art.occupied:
            first_rect = (
                first.x + first_column * metrics.cell_width + inset_x,
                first.y + first_row * metrics.line_height + inset_y,
                first.x + (first_column + 1) * metrics.cell_width - inset_x,
                first.y + (first_row + 1) * metrics.line_height - inset_y,
            )
            for second_column, second_row in second.art.occupied:
                second_rect = (
                    second.x + second_column * metrics.cell_width + inset_x,
                    second.y + second_row * metrics.line_height + inset_y,
                    second.x + (second_column + 1) * metrics.cell_width - inset_x,
                    second.y + (second_row + 1) * metrics.line_height - inset_y,
                )
                if rectangles_overlap(first_rect, second_rect):
                    return True
        return False

