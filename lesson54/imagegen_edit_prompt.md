# Lesson 54 — targeted visual QA correction

Preserve the generated layout and make only these evidence-critical corrections:

1. In ACK_EARLY, label the four consumers exactly `W0, W1, W2, W3`.
2. Replace the history card with:
   - `历史警示｜20次通过 ≠ 无竞态`
   - `Phase73：direct 20/20；Graph 已漂移`
   - `Phase79：direct 100次也漂移`
   - `0.617 ms / 1.493× 已撤回`
3. In the broken READY lane, show `TMA1 尚未发出` as inactive/locked, with no green completion mark.
4. Preserve all audited invariants: four 8 KiB rooms, two 16 KiB TMA transfers, masks `1100/0000`, ACK thresholds `3/4` and `4`, separate debug/release hashes, and no proposed-performance claim.
