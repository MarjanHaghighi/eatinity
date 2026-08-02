const MANAGEMENT_GROUPS = ["super-admin", "admin", "manager"];

const TRANSITIONS = {
  Pending: ["Confirmed", "Cancelled"],
  Confirmed: ["Preparing", "Cancelled"],
  Preparing: ["Ready for Pickup", "Out for Delivery", "Cancelled"],
  "Ready for Pickup": ["Picked Up"],
  "Picked Up": ["Completed"],
  "Out for Delivery": ["Delivered"],
};

const KITCHEN_TRANSITIONS = new Set([
  "Confirmed|Preparing",
  "Preparing|Ready for Pickup",
  "Preparing|Out for Delivery",
]);

const PICKUP_STATUS_PATH = ["Pending", "Confirmed", "Preparing", "Ready for Pickup", "Picked Up", "Completed"];
const DELIVERY_STATUS_PATH = ["Pending", "Confirmed", "Preparing", "Out for Delivery", "Delivered"];

export function getNextOrderStatuses(order, groups = []) {
  const current = order?.orderStatus || "Pending";
  let statuses = TRANSITIONS[current] || [];
  const delivery = String(order?.deliveryMethod || "Pickup").toLowerCase() === "delivery";

  if (groups.some((group) => MANAGEMENT_GROUPS.includes(group))) {
    const path = delivery ? DELIVERY_STATUS_PATH : PICKUP_STATUS_PATH;
    const currentIndex = path.indexOf(current);
    const futureStatuses = currentIndex >= 0 ? path.slice(currentIndex + 1) : [];
    return [
      ...futureStatuses,
      ...(!["Completed", "Delivered", "Cancelled"].includes(current) ? ["Cancelled"] : []),
    ];
  }

  if (current === "Preparing") {
    statuses = statuses.filter((status) =>
      status === "Cancelled" || status === (delivery ? "Out for Delivery" : "Ready for Pickup")
    );
  }

  statuses = statuses.filter((status) => KITCHEN_TRANSITIONS.has(`${current}|${status}`));

  return statuses;
}
