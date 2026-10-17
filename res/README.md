# iLiberated artwork

The app icon is an original open frame with an `iL` monogram and escaping pixels.
The logo pairs it with the iLiberated name. Both use a navy, mint and white palette
and replace the reserved iDared artwork. These assets are licensed under MPL-2.0.

`icon.svg` and `logo.svg` are vector versions. The wordmark uses outlined glyphs
from the bundled Liberation Sans Bold font, under the license in
`touchHLE_fonts/LICENSE.liberation`.

To regenerate all vector and PNG assets, install Python 3 and the Cairo and
FreeType shared libraries, then run from the repository root:

```sh
python3 dev-scripts/generate-branding.py
```

Edit the geometry and palette in that script. It renders the 1024-pixel iOS icon,
the 512-pixel shared icon (also used by Android through its existing symlink), and
the native app picker's wordmark. Keep the SwiftUI header palette in
`iphone/iLiberated/AppPicker.swift` consistent with it.
