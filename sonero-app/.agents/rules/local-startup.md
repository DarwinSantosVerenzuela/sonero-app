# Regla: Arranque Local del Proyecto Sonero

Cuando el usuario pida **ejecutar/arrancar/correr el proyecto en local**, SIEMPRE se deben levantar **ambos servicios** en este orden:

## 1. Backend API (sonero-api)

```powershell
& "c:\Users\dsantos\Desktop\sonitdo\Sonero V2\sonero-api\venv\Scripts\python.exe" main.py
```

- Directorio de trabajo: `c:\Users\dsantos\Desktop\sonitdo\Sonero V2\sonero-api`
- Se ejecuta como daemon (background)
- Esperar a que responda en `http://127.0.0.1:8000/health` antes de continuar
- Es un servidor FastAPI con Uvicorn

## 2. Frontend Flutter (sonero-app)

```powershell
flutter run -d chrome --web-port 3000
```

- Directorio de trabajo: `c:\Users\dsantos\Desktop\sonitdo\Sonero V2\sonero-app`
- Se ejecuta como daemon (background)
- El frontend espera el backend en `http://127.0.0.1:8000`
- El usuario espera ver la app en `http://localhost:3000`

## Notas importantes

- **Siempre** levantar el backend PRIMERO, luego el frontend.
- Las rutas con espacios deben ir entre comillas y usar `&` en PowerShell.
- El backend usa un virtualenv de Python ubicado en `sonero-api\venv\`.
- NO correr Flutter en modo Windows (`-d windows`) porque requiere Developer Mode habilitado.
- El usuario se refiere a esto como "correr en localhost" o "ejecutar en local".
