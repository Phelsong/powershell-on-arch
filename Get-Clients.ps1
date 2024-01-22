
if ($args[0]) {
    hyprctl clients | Select-String $args[0]
}
else {
    hyprctl clients
}
