type DragAxis = "x" | "y" | "both";

export function enableDragScroll(element: HTMLElement, axis: DragAxis = "x"): void {
  if (element.dataset.dragScrollBound === "true") {
    return;
  }

  element.dataset.dragScrollBound = "true";
  element.style.cursor = "grab";
  element.style.userSelect = "none";
  element.style.webkitUserSelect = "none";
  element.style.touchAction = axis === "x" ? "pan-x" : axis === "y" ? "pan-y" : "none";

  let activePointerId: number | null = null;
  let startX = 0;
  let startY = 0;
  let startScrollLeft = 0;
  let startScrollTop = 0;
  let moved = false;
  let dragging = false;

  element.addEventListener("pointerdown", (event) => {
    activePointerId = event.pointerId;
    startX = event.clientX;
    startY = event.clientY;
    startScrollLeft = element.scrollLeft;
    startScrollTop = element.scrollTop;
    moved = false;
    dragging = false;
  });

  element.addEventListener("pointermove", (event) => {
    if (activePointerId !== event.pointerId) {
      return;
    }

    const deltaX = event.clientX - startX;
    const deltaY = event.clientY - startY;
    if (Math.abs(deltaX) > 4 || Math.abs(deltaY) > 4) {
      moved = true;
      dragging = true;
      element.dataset.dragScrolling = "true";
      element.style.cursor = "grabbing";
    }

    if (!dragging) {
      return;
    }

    if (axis === "x" || axis === "both") {
      element.scrollLeft = startScrollLeft - deltaX;
    }

    if (axis === "y" || axis === "both") {
      element.scrollTop = startScrollTop - deltaY;
    }
  });

  const clearDragState = (pointerId: number) => {
    if (activePointerId !== pointerId) {
      return;
    }

    activePointerId = null;
    dragging = false;
    element.style.cursor = "grab";
    window.setTimeout(() => {
      if (moved) {
        delete element.dataset.dragScrolling;
      }
      moved = false;
    }, 0);
  };

  element.addEventListener("pointerup", (event) => clearDragState(event.pointerId));
  element.addEventListener("pointercancel", (event) => clearDragState(event.pointerId));
  element.addEventListener(
    "click",
    (event) => {
      if (element.dataset.dragScrolling === "true") {
        event.preventDefault();
        event.stopPropagation();
      }
    },
    true
  );
}
