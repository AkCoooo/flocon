<p align="center">
  <img src="docs/icon.png" width="160" height="160" alt="Icône de Flocon">
</p>

<h1 align="center">Flocon</h1>

<p align="center">
  <strong>Il neige sur ton Mac.</strong><br>
  La neige tombe sur ton bureau, se pose sur tes fenêtres, ton Dock et tes dossiers,<br>
  et un bonhomme de neige vient parfois te dire bonjour.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-0F1F52?style=flat-square&logo=apple&logoColor=white" alt="macOS 14 ou plus">
  <img src="https://img.shields.io/badge/Swift-5.10-3F72D9?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.10">
  <img src="https://img.shields.io/badge/AppKit-natif-E1EDFF?style=flat-square" alt="AppKit natif">
</p>

<p align="center">
  <a href="#installer"><strong>Installer Flocon</strong></a>
  &nbsp;·&nbsp;
  <a href="#ce-qui-se-passe-sur-ton-bureau">Voir ce qu'il fait</a>
  &nbsp;·&nbsp;
  <a href="#le-menu-">Le menu</a>
</p>

---

## Ce qui se passe sur ton bureau

- **La neige tient.** Elle s'accumule sur le haut des fenêtres, sur le Dock, sur les icônes du bureau et sur les widgets, en suivant leurs coins arrondis.
- **Elle tombe en mottes.** Bouge une fenêtre enneigée : sa neige se détache et dégringole.
- **Des stalactites poussent** sous les fenêtres qu'on laisse tranquilles.
- **Un bonhomme de neige** se construit de temps en temps sur le Dock. Il cligne des yeux, regarde autour de lui, salue, sautille, lance des boules de neige, puis fond.
- **Il sait se faire oublier.** Dès qu'un écran passe en plein écran, Flocon se met en veille sur tous les écrans et ne calcule plus rien. Les clics traversent la neige : rien ne gêne ton travail.

## Installer

Il faut macOS 14 ou plus récent et les outils de ligne de commande d'Xcode (`xcode-select --install`).

```bash
git clone https://github.com/AkCoooo/flocon.git
cd flocon
./build-app.sh
```

Le script compile, emballe `Flocon.app` avec son icône, la signe et l'installe dans `~/Applications`. Ouvre-la : un flocon ❄︎ apparaît dans la barre des menus, et il commence à neiger.

> [!TIP]
> Pour garder l'autorisation Accessibilité d'une version à l'autre, crée une fois un certificat de signature de code nommé `Flocon Dev` (Trousseaux d'accès › Assistant de certification › Créer un certificat, type « Signature de code », puis « Toujours approuver »). Sans lui, la signature change à chaque build et macOS redemande l'autorisation.

## Autorisation

La neige sur le Dock et les icônes du bureau passe par l'API d'Accessibilité : Flocon demande où ils se trouvent pour savoir où poser la neige. Le menu propose **Autoriser la neige sur le Dock…** tant que l'accès n'est pas donné. Sans l'autorisation, il neige quand même sur les fenêtres et les widgets.

## Le menu ❄︎

| Entrée | Ce qu'elle fait |
|---|---|
| **Faire neiger** | Lance ou arrête la neige |
| **Quantité** | Légère, Normale ou Tempête |
| **Bonhomme de neige** | L'afficher, le laisser lancer des boules de neige, ou en construire un tout de suite |
| **Réglages** | Neige qui tient vite, ouvrir au démarrage du Mac |

## Sous le capot

| Fichier | Rôle |
|---|---|
| `AppDelegate.swift` | Une vitre transparente par écran, et le menu ❄︎ |
| `SnowView.swift` | Le moteur : chute, atterrissage, tas, mottes, dessin |
| `Pile.swift` | Un tas de neige en colonnes, qui suit les coins arrondis |
| `WindowTracker.swift` | Où sont les fenêtres et les widgets |
| `DockLocator.swift`, `DesktopIcons.swift` | Ce que l'Accessibilité dit du Dock et du bureau |
| `Icicles.swift` | Les stalactites |
| `Clump.swift` | Les mottes qui tombent quand une fenêtre bouge |
| `Snowman.swift` | Le bonhomme de neige |
