"""Write Finder layout without depending on running Finder windows."""
from pathlib import Path
import sys

from ds_store import DSStore
from mac_alias import Alias

mount = Path(sys.argv[1]).resolve()
background_alias = Alias.for_file(str(mount / '.background/installer.png'))
assert background_alias.target.posix_path.lstrip(b'/') == b'.background/installer.png'
with DSStore.open(str(mount / '.DS_Store'), 'w+') as store:
    store['.']['vSrn'] = ('long', 1)
    store['.']['icvl'] = ('type', 'icnv')
    store['.']['bwsp'] = {
        'WindowBounds': '{{160, 100}, {720, 520}}',
        'ShowStatusBar': False, 'ShowToolbar': False, 'ShowSidebar': False,
        'ShowTabView': False, 'ShowPathbar': False,
        'ContainerShowSidebar': False, 'PreviewPaneVisibility': False,
        'SidebarWidth': 0,
    }
    store['.']['icvp'] = {
        'viewOptionsVersion': 1, 'backgroundType': 2,
        'backgroundColorRed': 1.0, 'backgroundColorGreen': 1.0, 'backgroundColorBlue': 1.0,
        'backgroundImageAlias': background_alias.to_bytes(),
        'gridOffsetX': 0.0, 'gridOffsetY': 0.0, 'gridSpacing': 100.0,
        'arrangeBy': 'none', 'showIconPreview': True, 'showItemInfo': False,
        'labelOnBottom': True, 'textSize': 13.0, 'iconSize': 88.0,
        'scrollPositionX': 0.0, 'scrollPositionY': 0.0,
    }
    store['Window Peek.app']['Iloc'] = (180, 246)
    store['Applications']['Iloc'] = (540, 246)

with DSStore.open(str(mount / '.DS_Store'), 'r') as store:
    assert store['Window Peek.app']['Iloc'] == (180, 246)
    assert store['Applications']['Iloc'] == (540, 246)
