import runpy
import sys

sys.path.insert(0, r"C:\Marjan\Eatinity\.docx_deps")
sys.argv = [
    "render_docx.py",
    r"C:\Marjan\Eatinity\Eatinity_Disaster_Recovery_Plan.docx",
    "--output_dir",
    r"C:\Marjan\Eatinity\.dr_report_render",
    "--emit_pdf",
]
runpy.run_path(
    r"C:\Users\haghm\.codex\plugins\cache\openai-primary-runtime\documents\26.630.12135\skills\documents\render_docx.py",
    run_name="__main__",
)
