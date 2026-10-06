
import subprocess, threading, time, os
def godot_bg(args, log, timeout=420):
    """Run Godot detached from Blender's main thread; output -> log file; killed after timeout."""
    G=r"D:\Godot\Godot_v4.7.2-stable_win64_console.exe"
    def work():
        with open(log,"w",encoding="utf-8",errors="replace") as f:
            f.write("STARTED %s\n" % time.ctime()); f.flush()
            pr=subprocess.Popen([G]+args,stdout=f,stderr=subprocess.STDOUT)
            try:
                pr.wait(timeout=timeout); f.write("\nEXIT %s\n" % pr.returncode)
            except subprocess.TimeoutExpired:
                pr.kill(); f.write("\nKILLED (timeout)\n")
    threading.Thread(target=work,daemon=True).start()
