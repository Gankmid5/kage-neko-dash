# Publishing Kage-Neko Dash to itch.io

`export_presets.cfg` is pre-configured with a **Web (itch.io)** preset (single-threaded WebGL / GL Compatibility, adaptive canvas resize, no `SharedArrayBuffer` requirement).

## Steps to Export & Upload

1. Open `project.godot` in **Godot 4**.
2. If you haven't installed Web export templates yet: **Editor → Manage Export Templates… → Download and Install**.
3. Go to **Project → Export…** and select **Web (itch.io)**.
4. Click **Export Project…** (default path: `build/web/index.html`) with **Export With Debug** unchecked.
5. Zip the **contents** of `build/web/` (so `index.html` is at the root of the `.zip`, not inside a subfolder).
6. On **itch.io → Dashboard → Create new project**:
   - **Kind of project:** HTML
   - **Cover image:** Upload `itch_cover.jpg`
   - Upload your `.zip` and check **This file will be played in the browser**
   - **Viewport dimensions:** `1280` × `720`
   - **Fullscreen button:** Enabled
   - Click **Save & view page**!
