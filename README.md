# App-Android-iOS
Desarrollo de una aplicacion móvil nativa para el ecosistema Android y Apple, interactuando con recursos del dispositivo e implementando almacenamiento local.

---
## Información de la materia
* Aplicaciones Móviles Nativas 
* Profesor Gabriel Hurtado Avilés 
* Grupp 7CV4

## Participantes
* Chávez Romero Jonathan - 2024630102
* Moreno Noguerón Ximena - 2024630201
* Reyes Castellanos José Abel - 2020311353

## Estructura del repositorio

```
├── Ejercicio1/        Manual de instalación para desarrollo de iOS y proyecto de prueba
├── Ejercicio2/        Gestor de archivos con iOS
├── Ejercicio3/        Aplicación de cámara y micrófono con iOS
├── Ejercicio4/        Aplicación de cámara y micrófono con Flutter (Android y iOS)
└── README.md
```

## índice
* [`Ejercicio1/`](ejercicio_1_instalacion/README.md)
* [`Ejercicio2/`](ejercicio_2_gestor_archivos/GestorArchivos//README.md)
* [`Ejercicio3/`](ejercicio_3_camara_microfono/CamaraMicrofono/CamaraMicrofono/README.md)
* [`Ejercicio4/`](Ejercicio4/app_cam_micr/README.md)

## Forma de trabajo
Para evitar sobreescrituras y gestionar los tiempos del equipo con una clara coordinación, se realiza la implementación de **ramas enfocadas en tareas**. Cada persona crea una rama específica para la tarea concreta que se desea resolver, cuando la rama contenga todo el desarrollo de la tarea que almacena, se abre un **Pull request** para integrar sus cambios a la rama principal *master*, alguno de los compañeros que no trabajo en la rama realiza su revisión.

### Consideraciones necesarias
1. Realizar una sincronización local antes de empezar a trabajar:
    ``` bash
        git checkout master
        git pull origin master
    ```

2. Crear una rama de acuerdo a la funcionalidad a realizar:
    ``` bash
        git checkout -b [nombre-rama]
    ```

3. Agregar el trabajo realizado junto con su commit:
    ``` bash
        git add .
        git commit -m "Descripción"
    ```

4. Subir la rama al repositorio remoto (GitHub):
    ``` bash
        git push origin [nombre-rama]
    ```

5. Abrir un Pull Request desde la plataforma de GitHub.