# Flocon

Petite app macOS qui fait neiger sur le bureau. La neige se pose sur les fenêtres, le Dock, les dossiers et les widgets, tombe en mottes quand on bouge une fenêtre, et des stalactites poussent sous les fenêtres immobiles. De temps en temps, un bonhomme de neige se construit sur le Dock, salue, lance des boules de neige, puis fond.

## Construire et installer

Il faut macOS 14 ou plus récent et les outils de ligne de commande d'Xcode (`xcode-select --install`).

```bash
./build-app.sh
```

Le script compile, emballe `Flocon.app` avec son icône, la signe et l'installe dans `~/Applications`.

Pour garder l'autorisation Accessibilité d'une version à l'autre, crée une fois un certificat de signature de code nommé `Flocon Dev` (Trousseaux d'accès › Assistant de certification › Créer un certificat, type « Signature de code », puis « Toujours approuver »). Sans lui, la signature change à chaque build et macOS redemande l'autorisation.

## Autorisation

La neige sur le Dock, les icônes du bureau et la détection du plein écran passent par l'API d'Accessibilité. Sans l'autorisation, il neige quand même sur les fenêtres et les widgets.

## Organisation

| Fichier | Rôle |
|---|---|
| `AppDelegate.swift` | Une vitre transparente par écran, et le menu ❄︎ |
| `SnowView.swift` | Le moteur : chute, atterrissage, tas, mottes, dessin |
| `Pile.swift` | Un tas de neige en colonnes, qui suit les coins arrondis |
| `WindowTracker.swift` | Où sont les fenêtres et les widgets |
| `DockLocator.swift`, `DesktopIcons.swift`, `FullScreenDetector.swift` | Ce que l'Accessibilité dit du Dock, du bureau et du plein écran |
| `Icicles.swift` | Les stalactites |
| `Clump.swift` | Les mottes qui tombent quand une fenêtre bouge |
| `Snowman.swift` | Le bonhomme de neige |
| `Sprites.swift` | Petites images dessinées au démarrage |
