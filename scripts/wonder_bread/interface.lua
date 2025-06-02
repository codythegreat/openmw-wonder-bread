local I = require("openmw.interfaces")
local input = require("openmw.input")


I.Settings.registerPage({
   key = "wonderbread",
   l10n = "wonderbread",
   name = "Wonder Bread",
   description = "Create bread in real time, similar to the game Arx Fatalis.",
})

I.Settings.registerGroup({
   key = "Settings_wonderbread",
   page = "wonderbread",
   l10n = "wonderbread",
   name = "Wonder Bread",
   permanentStorage = true,
   settings = {
      {
        key = "actionHotkey",
        default = input.KEY.B,
        renderer = "inputKeyBox",
        name = "Hotkey",
        description = "Changes the hotkey used for filling bottles and creating dough.",
     },
     {
        key = "debugLoggingEnabled",
        default = false,
        renderer = "checkbox",
        name = "Enable Debug Logging",
        description = "If checked, enables detailed debug messages in the console.",
      },
   },
})

return