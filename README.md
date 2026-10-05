# Astralis

> 🚧 **Astralis is currently in development.**

Astralis is a game project developed with [Godot Engine](https://godotengine.org/).

The project is currently in an early stage of development. The gameplay, mechanics, content and overall experience are actively being developed and may change significantly during development.

## 🎮 About the project

Astralis is a personal game development project focused on experimenting with Godot and building the foundations of a complete game.

The project is currently under active development and is not yet considered a finished or stable release.

More information about the gameplay and implemented features will be added as the project progresses.

## 🛠️ Technologies

| Technology | Version / Configuration |
|------------|-------------------------|
| [Godot Engine](https://godotengine.org/) | 4.7 |
| Language | GDScript |
| Renderer | GL Compatibility |
| 3D Physics | Jolt Physics |

The project uses Godot's compatibility renderer to maintain broad hardware compatibility.

## 🚀 Getting started

### Requirements

- [Godot Engine](https://godotengine.org/) 4.7
- Git

### Clone the repository

```bash
git clone https://github.com/koromerzhin/astralis.git
cd astralis
```

Then open the project with Godot by importing the `project.godot` file.

### Run the project

From the Godot editor, press **F6** to run the current scene or **F5** to run the main scene.

The project can also be launched from the command line:

```bash
godot --path .
```

## 📁 Project structure

```text
astralis/
├── .github/
│   ├── dependabot.yml
│   └── workflows/
│       └── ci.yml
├── scenes/
├── scripts/
├── icon.svg
├── project.godot
└── README.md
```

### Main directories

#### `scenes/`

Contains the Godot scenes used by Astralis.

#### `scripts/`

Contains the GDScript source code used to implement the project's gameplay and systems.

#### `.github/`

Contains the project's GitHub configuration.

The repository uses GitHub Actions for continuous integration and Dependabot to keep GitHub Actions dependencies up to date.

## 🧪 Continuous Integration

Astralis uses GitHub Actions to automatically validate the project.

The CI verifies that the project can be imported and opened correctly using the supported Godot version.

The workflow runs on:

- pushes to `main`;
- pushes to `develop`;
- pull requests targeting `main`;
- pull requests targeting `develop`.

## 📋 Development status

Astralis is currently under active development.

### Current goals

- [ ] Establish the core gameplay
- [ ] Develop the main gameplay systems
- [ ] Build the game world
- [ ] Develop the user interface
- [ ] Add audio and visual polish
- [ ] Add automated tests where appropriate
- [ ] Prepare the first playable release

This roadmap is intentionally kept flexible while the project's foundations are being developed.

## 🗺️ Roadmap

The roadmap will be updated as the project progresses.

### Foundation

- [x] Create the Godot project
- [x] Configure Godot 4.7
- [x] Configure the GL Compatibility renderer
- [x] Configure Jolt Physics
- [x] Set up the Git repository
- [x] Set up GitHub Actions
- [x] Set up Dependabot
- [ ] Establish the final project architecture

### Gameplay

- [ ] Define the core gameplay loop
- [ ] Implement the main gameplay mechanics
- [ ] Implement player interactions
- [ ] Implement game progression
- [ ] Add game feedback and polish

### Content

- [ ] Develop the game world
- [ ] Add visual assets
- [ ] Add sound effects
- [ ] Add music
- [ ] Add additional game content

### Release

- [ ] First playable prototype
- [ ] Internal testing
- [ ] First public build
- [ ] First stable release

## 🤝 Contributing

Astralis is primarily a personal development project.

Bug reports, suggestions and technical feedback are welcome.

If you find a problem with the project, please open a GitHub issue and provide enough information to reproduce it.

Before submitting a pull request, make sure that:

- the project opens correctly with Godot 4.7;
- the CI checks pass;
- no unnecessary generated files are included in the commit.

## 📜 License

Astralis is currently under development.

The project's license will be defined before the first public release.

## 👤 Author

**Koromerzhin**

[GitHub](https://github.com/koromerzhin)