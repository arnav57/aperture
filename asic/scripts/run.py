import os, sys, re
import argparse
from pathlib import Path
from cocotb_tools.runner import get_runner
from run_utils import build_blocks, create_sim_folder

import logging
logging.basicConfig(
    level=logging.INFO,
    format="[{name:^30}][{levelname:^8}]: {message}",
    style='{'
)

#### CLI Args

parser = argparse.ArgumentParser(
    description = "Run an RTL wavedump for a certain testcase"
)

parser.add_argument("-tb", "--tb",     type=str, required=True, help='what testbench do you want to run?')
parser.add_argument('-test', '--test', type=str, required=True, help='what testcase do you want to run?')
parser.add_argument('-top', '--top', type=str, required=True, help='what is the top level module for this run?')

#### MAIN METHOD

if __name__ == "__main__":
    logger = logging.getLogger("RUN :: main")
    args = vars(parser.parse_args())
    tb   = args['tb']
    test = args['test']
    top  = args['top']

    logger.info(f"Preparing to compile: tb={tb} and test={test}")
    blocks = build_blocks()

    # obtain the block
    block = blocks.get(tb, None)
    if block is None:
        logger.critical(f"tb={tb} is not a valid choice!\n\nValid choices are {blocks.keys()}")
        sys.exit(1)
    
    # obtain the testcase + path to testcase
    testcases_dict = {t.stem : t for t in block.testcases}
    if test not in testcases_dict.keys():
        logger.critical(f"test={test} is not a valid choice!\n\nValid choices are {testcases_dict.keys()}")
        sys.exit(1)
    testcase_path = testcases_dict[test]
    logger.info(f"Chosen testcase is at: {testcase_path}")

    # obtain + validate the top level module
    rtl_files = [t.stem for t in block.rtl_files]
    if top not in rtl_files:
        logger.critical(f"top={top} does not exist, or is not present in this block")
        sys.exit(1)

    # create the sim folder and run-command file
    sim_folder = create_sim_folder()
    py_exe  = sys.executable
    py_args = sys.argv
    run_cmd = f"{py_exe} " + " ".join(py_args)
    with open(str(sim_folder/'run_command'), 'w') as f:
        f.write(run_cmd)
    
    #### Start the build process
    logger.info(f"Setup Complete. Starting Compile ...")
    sim = "questa"
    runner = get_runner(sim)
    runner.build(
        sources = block.rtl_files,
        hdl_toplevel = top,
        build_dir = sim_folder,
        timescale = ('1ns', '1ps'),
        waves = True
    )
    sys.path.append(str(testcase_path.parent))
    runner.test(
        hdl_toplevel = top,
        test_module  = test,
        waves = True
    )





