"use strict";

// Animação estilo Launchpad do macOS para o Painel de aplicativos (kickerdash):
// abre vindo levemente ampliado com fade-in, fecha ampliando com fade-out.
const duration = animationTime(effect.readConfig("Duration", 260));
const inScale = effect.readConfig("InScale", 1.12);
const outScale = effect.readConfig("OutScale", 1.12);

function isDashboard(w) {
    return w.windowClass == "plasmashell org.kde.plasmashell"
        && w.normalWindow && w.fullScreen && !w.hasDecoration;
}

function forceRoles(w, on) {
    w.setData(Effect.WindowForceBlurRole, on ? true : null);
    w.setData(Effect.WindowForceBackgroundContrastRole, on ? true : null);
}

effect.animationEnded.connect(w => forceRoles(w, false));

effects.windowAdded.connect(w => {
    if (!isDashboard(w) || !w.visible) return;
    w.setData(Effect.WindowAddedGrabRole, effect);
    forceRoles(w, true);
    w.lpIn = animate({
        window: w, duration: duration, curve: QEasingCurve.OutCubic,
        animations: [
            { type: Effect.Scale, from: inScale },
            { type: Effect.Opacity, from: 0 }
        ]
    });
});

effects.windowClosed.connect(w => {
    if (!isDashboard(w) || !w.visible) return;
    if (w.lpIn) { cancel(w.lpIn); delete w.lpIn; }
    w.setData(Effect.WindowClosedGrabRole, effect);
    forceRoles(w, true);
    animate({
        window: w, duration: Math.round(duration * 0.85), curve: QEasingCurve.InCubic,
        animations: [
            { type: Effect.Scale, to: outScale },
            { type: Effect.Opacity, to: 0 }
        ]
    });
});
