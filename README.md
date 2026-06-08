# Vessel

Vessel is an interactive, multi-physics simulation sandbox designed for mobile devices. It allows users to explore various physical and chemical phenomena within a dynamically adjustable polygonal boundary. The application combines real-time fluid dynamics, electromagnetism, and reaction-diffusion systems into a seamless, visually stunning experience.

## Features

### 1. Dynamic Polygonal Boundary
The simulation takes place within a regular polygon whose number of vertices ($N$) can be adjusted in real-time from $N=3$ (Triangle) up to $N=16$ (Hexadecagon). This $N$ slider is conveniently located in the header for quick access. The boundary acts as a physical wall, reflecting waves, confining particles, and shaping the electric fields.

### 2. Immersive 3-Step UI Toggle
To maximize the visual experience, Vessel features a 3-step UI toggle system controlled by the bottom-right icon in the header:
- **Step 0 (Header Only)**: Displays the top header with Rule selection, $N$ slider, and Restart button.
- **Step 1 (Parameters Open)**: Expands the parameter tab below the header, revealing rule-specific sliders (e.g., Damping, Charge, Interaction Strength) for the currently active simulation rule.
- **Step 2 (Minimal View)**: Hides all UI elements (header and parameter tab), leaving only the simulation canvas for complete immersion. A subtle transparent icon remains in the top-right corner to restore the UI.

### 3. Real-time Interaction
Users can interact with the simulation by touching and dragging on the screen. Depending on the active rule, this action can generate waves, spawn particles, place electric charges, or shoot dipoles.

## Physics Rules

Vessel currently implements the following simulation rules:

- **Wave**: A classic 2D wave equation solver. Touching the screen generates ripples that reflect off the polygonal boundaries.
- **Gravity**: An N-body gravity simulation. Particles are attracted to each other and bounce off the walls. The gravitational constant ($G$) automatically scales with the polygon's size.
- **Electric**: An electrostatic field simulation. Users can place positive or negative monopoles. The field potential is visualized with smooth contours, and the zero-potential boundary glows brilliantly in white.
- **Dipole**: An advanced electromagnetic simulation. Users can shoot electric dipoles by dragging. Dipoles interact via torque and translational forces, align with each other, and can undergo **annihilation** upon contact, releasing a powerful electromagnetic pulse (radiation) that propagates across the grid.
- **Heat**: A thermal diffusion simulation. Touching the screen injects heat, which slowly diffuses and dissipates over time.
- **Gray-Scott**: A reaction-diffusion system that generates complex, organic-looking Turing patterns.
- **BZ (Belousov-Zhabotinsky)**: An oscillating chemical reaction simulation that produces mesmerizing spiral waves.
- **Life**: Conway's Game of Life adapted for a continuous grid, featuring crisp, unblurred cellular automata evolution.
- **Arc**: A high-voltage electrical discharge simulation. It solves the Laplace equation to find the electric potential and traces stochastic, branching lightning bolts from the center to the grounded polygonal boundary.

## Build Instructions

### Prerequisites
- Flutter SDK (Channel stable, 3.24.0 or higher)
- Android Studio / Xcode for mobile deployment

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/suginole/vessel.git
   cd vessel
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Generate icons and splash screens (Required before first build):
   ```bash
   flutter pub run flutter_launcher_icons
   flutter pub run flutter_native_splash:create
   ```

### Android Deployment
The project is configured for Android deployment with `minSdkVersion 21` and `targetSdkVersion 34`.
To build a release AppBundle:
1. Ensure you have a valid keystore file (`.jks`).
2. Create `android/key.properties` with your keystore details:
   ```properties
   storePassword=YOUR_PASSWORD
   keyPassword=YOUR_PASSWORD
   keyAlias=YOUR_ALIAS
   storeFile=/path/to/your/keystore.jks
   ```
3. Build the AppBundle:
   ```bash
   flutter build appbundle --release
   ```

## プライバシーポリシー / Privacy Policy

Vessel アプリは個人情報を一切収集しません。

- 収集するデータ：なし
- 第三者への提供：なし
- 広告：なし
- ネットワーク通信：なし

This app does not collect any personal information.

- Data collected: None
- Third-party sharing: None
- Advertising: None
- Network communication: None

お問い合わせ / Contact: pieuj3610.jin@gmail.com

最終更新 / Last updated: 2025-06

