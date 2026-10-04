from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict
from pprint import pformat, pprint
from datetime import datetime

import logging
logging.basicConfig(
    level=logging.INFO,
    format="[{name:^30}][{levelname:^8}]: {message}",
    style='{'
)
#### FILEPATHS

ASIC_ROOT    = Path(__file__).parent.parent.resolve()
ASIC_EXTERNAL= ASIC_ROOT / 'external'
ASIC_SCRIPTS = ASIC_ROOT / 'scripts'
ASIC_DESIGN  = ASIC_ROOT / 'design'
ASIC_DV      = ASIC_ROOT / 'dv'

@dataclass
class Block:
    name: str
    testcases: Dict[str, Path]
    rtl_files: List[Path]
    aux_files: List[Path] | None = None

@dataclass
class Library:
    name: str
    rtl_dir: Path

def validate_paths():
    # check if asic-scripts/design/dv exist
    logger = logging.getLogger("RUN-UTILS :: validate_paths")
    for path in [ASIC_ROOT, ASIC_DESIGN, ASIC_DV, ASIC_SCRIPTS, ASIC_EXTERNAL]:
        if path.exists() and path.is_dir():
            next
        else:
            raise RuntimeError(f"Something went wrong. {path} does not exist, or is not a directory")
    
    logger.info(f"Validated ASIC_ROOT at:    {ASIC_ROOT}")
    logger.info(f"Validated ASIC_DESIGN at:  {ASIC_DESIGN}")
    logger.info(f"Validated ASIC_DV at:      {ASIC_DV}")
    logger.info(f"Validated ASIC_SCRIPTS at: {ASIC_SCRIPTS}")


def build_blocks() -> Dict[str, Block]:
    validate_paths()

    logger = logging.getLogger("RUN-UTILS :: build_blocks")

    # start by checking each directory in design
    design_dirs = [f.name for f in ASIC_DESIGN.iterdir() if f.is_dir()]
    dv_dirs     = [f.name for f in ASIC_DV.iterdir() if f.is_dir()]
    
    # join both lists to create a basic dict with block names first
    # only use the blocks in both lists
    block_level_dirs = list(set(design_dirs) & set(dv_dirs))
    logger.info(f"Found {len(block_level_dirs)} block level directories: {block_level_dirs}")

    blocks = {}
    
    for bldir in block_level_dirs:
        logger.info(f"Parsing block level directories for '{bldir}'")
        design_path = ASIC_DESIGN / bldir
        dv_path     = ASIC_DV / bldir

        # get the RTL
        rtl_exts  = ['.sv', '.v']
        rtl_path  = design_path / 'rtl'
        rtl_files = []
        if rtl_path.is_dir():
            rtl_files = [f for f in rtl_path.iterdir() if f.is_file() and f.suffix in rtl_exts]
        logger.info(f"Found {len(rtl_files)} RTL files")


        # get the Testcases supported
        test_exts = ['.py']
        test_path = dv_path / 'tests'
        testcases = []
        if test_path.is_dir():
            testcases = [f for f in test_path.iterdir() if f.is_file() and f.suffix in test_exts]
        logger.info(f"Found {len(testcases)} testcases")
        # get the aux sources 
        aux_dv_path   = dv_path / 'misc'
        aux_rtl_path  = design_path / 'misc'

        aux_dv_files = []
        aux_rtl_files = []

        if aux_dv_path.is_dir():
            aux_dv_files  = [f for f in aux_dv_path.iterdir() if f.is_file() and f.suffix in test_exts]
        
        if aux_rtl_path.is_dir():
            aux_rtl_files = [f for f in aux_rtl_path.iterdir() if f.is_file() and f.suffix in rtl_exts]

        rtl_files += aux_rtl_files 
        rtl_files += aux_dv_files
        logger.info(f"Found {len(aux_rtl_files) + len(aux_dv_files)} aux files")

        # create a block object from this data, add it to the dict
        block = Block(
            name = bldir,
            testcases = testcases,
            rtl_files = rtl_files,
            aux_files = aux_rtl_files + aux_dv_files
        )
        blocks.setdefault(bldir, block)
    
    return blocks


def create_sim_folder():
    now = datetime.now().strftime("%B%d_%H%M%S")
    sim_folder = ASIC_ROOT / 'sim' / now
    sim_folder.mkdir(parents=True, exist_ok=True)
    return sim_folder


def get_lib_dirs(exclude:str = None) -> List[Path]:
    dirs = []
    for d in sorted(ASIC_DESIGN.iterdir()):
        if not d.is_dir() or d.name == exclude:
            continue
        rtl_dir = d / 'rtl'
        if rtl_dir.is_dir():
            dirs.append(rtl_dir)
    return dirs

def get_external_libs() -> List[Path]:
    libs = []

    for lib in sorted(ASIC_EXTERNAL.iterdir()):

        if not lib.is_dir():
            continue
        
        rtl_dir = lib / 'rtl'
        if rtl_dir.is_dir():
            libs.append(rtl_dir)
    
    return libs