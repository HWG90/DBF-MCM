# MCM 0.1.72 - conditional controls

Add enabled_if, disabled_if and visible_if predicates with draft-aware getters, set_condition and explicit refresh. Forward legacy registry invalidation to the main catalogue, preserve imported ownership, and retain saved values while cancelling unavailable drafts. Reject stale slider releases safely. DBF random input delay now disables its fixed delay against the current draft. Condition callback errors fail closed without closing the menu. Evaluations occur on mutation or explicit refresh, not during idle drawing.

Local deployment and live acceptance are recorded under dist/conditional-controls; public publication is not part of this fix.
