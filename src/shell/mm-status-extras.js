// Extras que outras extensões acrescentam ao menu de sistema.
//
// Elas gravam em Main.panel.statusArea.aggregateMenu — o objeto do monitor
// primário, buscado por nome — então o menu desta tela, que é uma instância
// própria, nasce sem nada disso. Só dá para reexecutar o que a extensão expõe
// no escopo do módulo, e em GJS apenas `var`/`function` de topo viram
// propriedade importável:
//
//   sound-output-device-chooser  exporta `var SDCInstance`  -> instanciável
//   big-avatar                   guarda o item em global    -> refeito aqui
//   bluetooth-quick-connect      classe não exportada       -> só no primário
//   system76-power               guarda `if (null === ext)` -> só no primário
//
// Tudo em try/catch: isto depende do miolo de extensões de terceiros. Se uma
// delas mudar de forma, esta tela perde o extra e o painel segue de pé.
function _addStatusExtras(aggregateMenu) {
    let extras = { sdc: null, avatarItem: null };

    try {
        let sdcExt = Main.extensionManager.lookup('sound-output-device-chooser@kgshank.net');
        let SDCInstance = sdcExt && sdcExt.imports && sdcExt.imports.extension.SDCInstance;
        if (SDCInstance) {
            // O enable() lê Main.panel.statusArea.aggregateMenu direto; apontamos
            // para o menu desta tela só durante a construção.
            let real = Main.panel.statusArea.aggregateMenu;
            Main.panel.statusArea.aggregateMenu = aggregateMenu;
            try {
                extras.sdc = new SDCInstance();
                extras.sdc.enable();
            } finally {
                Main.panel.statusArea.aggregateMenu = real;
            }
        }
    } catch (e) {
        global.log('multi-monitors-add-on: seletor de audio nao replicado: ' + e);
        extras.sdc = null;
    }

    try {
        let avExt = Main.extensionManager.lookup('big-avatar@gustavoperedo.org');
        if (avExt) {
            let item = new PopupMenu.PopupMenuItem('');
            let box = new St.BoxLayout({ x_expand: true, y_expand: true, vertical: true });
            item.add_child(box);
            let user = AccountsService.UserManager.get_default().get_user(GLib.get_user_name());
            let avatar = new UserWidget.UserWidget(user, Clutter.Orientation.VERTICAL);
            avatar._updateUser();
            box.add_child(avatar);
            aggregateMenu.menu.addMenuItem(item, 0);
            extras.avatarItem = item;
        }
    } catch (e) {
        global.log('multi-monitors-add-on: avatar nao replicado: ' + e);
        extras.avatarItem = null;
    }

    return extras;
}

function _removeStatusExtras(extras) {
    if (!extras)
        return;
    try {
        if (extras.sdc)
            extras.sdc.disable();
    } catch (e) {
        global.log('multi-monitors-add-on: falha ao desmontar seletor de audio: ' + e);
    }
    try {
        if (extras.avatarItem)
            extras.avatarItem.destroy();
    } catch (e) {
        global.log('multi-monitors-add-on: falha ao desmontar avatar: ' + e);
    }
}
