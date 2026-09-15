@echo off
title Vigilis YOLO + OpenCV AI Service
echo ========================================================
echo       VIGILIS YOLO + OPENCV AI DETECTION SERVICE
echo ========================================================
echo.
cd /d %~dp0

echo Checking Python dependencies...
python -m pip install -r requirements.txt

echo.
echo Starting FastAPI AI Vision Microservice on port 5001...
python main.py
pause
