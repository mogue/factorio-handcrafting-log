data:extend({
    {
      type = "custom-input",
      name = "handcrafting-queue-log",
      key_sequence = "F10",
    },
    {
        type = "shortcut",
        name = "handcrafting-queue-log-shortcut",
        order = "d[tools]-r[handcrafting-queue-log]",
        icon = "__base__/graphics/icons/shortcut-toolbar/mip/new-blueprint-book-x32.png",
        icon_size = 32,
        small_icon = "__base__/graphics/icons/shortcut-toolbar/mip/new-blueprint-book-x24.png",
        small_icon_size = 24,
        style = "green",
        action = "lua",
        associated_control_input = "handcrafting-queue-log",
    }
})