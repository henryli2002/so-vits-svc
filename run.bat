@echo off
REM Step 1: Activate AudioTool environment and run Separator.py
call conda activate AudioTool
python Separator.py
call conda deactivate

REM Step 2: Activate SVC environment
call conda activate SVC

REM Step 3: Process files in the raw folder
set raw_folder=raw
for %%f in (%raw_folder%\*.wav) do (
    set file_name=%%~nf
    call python inference_main.py -m "logs/44k/G_79200.pth" -c "configs/config.json" -n "%%~nf.wav" -t 0 -s "Ava" -cl 60
)

REM Step 4: Clear the raw folder
del /Q %raw_folder%\*.wav

call conda deactivate

REM Step 5: Run PowerShell script
powershell -ExecutionPolicy Bypass -File merge_audio.ps1

echo All tasks completed successfully.
pause
