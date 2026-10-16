# Preview 0.1.64

Fixed the missing right-click menu on Mod Bindings Menu keyboard rows. Right-click a binding and choose **Unbind key**.

The 0.1.63 clear action existed but the native binding row did not register its mouse context handler. A regression test now right-clicks both standalone and nested native fields, checks that Unbind key is rendered, and clicks it through the mouse input path.

43 native-binding editor and transaction tests passed. Live unbind testing remains pending.

**Main:** BSL Standalone. **Optional:** combined MDL / LLL package. Install one instance and restart after updating.

Thanks to **Muchacho** for helping troubleshoot keybinding lookup issues.
