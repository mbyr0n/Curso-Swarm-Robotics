# Curso Swarm Robotics en Ubuntu 24.04

Este repositorio contiene material de practica para ARGoS3 usado en el curso
Swarm Robotics. La guia original fue pensada para Ubuntu 20.04; esta version
documenta una instalacion local reproducible en Ubuntu 24.04.

La idea es no versionar binarios ni instalaciones locales. ARGoS3 se compila en
tu maquina dentro de `argos3-dist/`, y los experimentos del curso usan esa
instalacion local.

## Contenido

- `aggregation/`: experimentos Lua de agregacion.
- `obstacle_avoidance/`: controlador Lua de evitacion de obstaculos.
- `pattern_formation/`: escenario base de formacion de patrones.
- `sandbox/`: escenario simple para pruebas.
- `foraging/`: experimento con loop function en C++.
- `install_argos3.sh`: script de compilacion local para Ubuntu 24.04.

No se suben al repositorio:

- `argos3/`: codigo fuente y build tree local de ARGoS3.
- `argos3-dist/`: instalacion local generada.
- `foraging/build/`: build del plugin de foraging.
- `backups/`: respaldos locales.
- `foraging/output.txt`: salida generada por simulaciones.

## Requisitos

Probado para Ubuntu 24.04. Instala las dependencias base:

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  cmake \
  git \
  libfreeimage-dev \
  libfreeimageplus-dev \
  qtbase5-dev \
  qtbase5-dev-tools \
  freeglut3-dev \
  libxi-dev \
  libxmu-dev \
  liblua5.3-dev \
  lua5.3 \
  doxygen \
  graphviz \
  libgraphviz-dev \
  asciidoc \
  libgl1-mesa-dev \
  libglu1-mesa-dev
```

En Ubuntu 24.04 no uses `qt5-default`; ese paquete ya no esta disponible. Usa
`qtbase5-dev` y `qtbase5-dev-tools`.

## Obtener ARGoS3

Clona ARGoS3 dentro de este repositorio con la estructura esperada por el
script:

```bash
git clone https://github.com/ilpincy/argos3.git argos3/src
```

La carpeta resultante debe verse asi:

```text
swarm_robotics/
  argos3/
    src/
  install_argos3.sh
  aggregation/
  foraging/
```

## Compilar e instalar ARGoS3 localmente

Ejecuta:

```bash
./install_argos3.sh
```

El script:

- configura ARGoS3 con CMake;
- compila en `argos3/build/`;
- instala en `argos3-dist/`;
- agrega un bloque de variables de entorno a `~/.bashrc` si no existe.

Carga el entorno en la terminal actual:

```bash
source ~/.bashrc
```

O exporta las variables manualmente:

```bash
export ARGOS_INSTALL_PATH="$PWD"
export CMAKE_PREFIX_PATH="$PWD/argos3-dist${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export ARGOS_PLUGIN_PATH="$PWD/argos3-dist/lib/argos3${ARGOS_PLUGIN_PATH:+:$ARGOS_PLUGIN_PATH}"
export LD_LIBRARY_PATH="$PWD/argos3-dist/lib:$PWD/argos3-dist/lib/argos3${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$PWD/argos3-dist/bin${PATH:+:$PATH}"
```

Verifica que ARGoS3 quedo disponible:

```bash
which argos3
argos3 --version
```

## Ejecutar experimentos Lua

Ejemplo de agregacion:

```bash
argos3 -c aggregation/aggregation_one_spot.argos
```

Otro escenario:

```bash
argos3 -c obstacle_avoidance/obstacle_avoidance_empty.argos
```

## Compilar y ejecutar foraging

El experimento `foraging` usa una loop function en C++. Compilala despues de
tener ARGoS3 instalado y las variables de entorno cargadas:

```bash
cmake -S foraging/src -B foraging/build
cmake --build foraging/build
```

Ejecuta el experimento desde la carpeta `foraging`, porque el archivo `.argos`
usa rutas relativas:

```bash
cd foraging
argos3 -c foraging.argos
```

## Pruebas rapidas de controladores Lua

Los controladores de agregacion incluyen pruebas pequenas ejecutables con Lua
5.3:

```bash
lua5.3 aggregation/test_aggregation_one.lua
lua5.3 aggregation/test_aggregation_two.lua
```

## Material del curso

Los experimentos implementan comportamientos descentralizados para enjambres de
foot-bots homogeneos. Cada robot ejecuta el mismo controlador y toma decisiones
con sensores locales.

### Obstacle avoidance

`obstacle_avoidance/ballistic_motion.lua` implementa una caminata aleatoria
balistica: el robot avanza hasta detectar un obstaculo frontal, gira en sitio
durante un intervalo aleatorio y luego vuelve a avanzar.

`obstacle_avoidance/obstacle_avoidance.lua` usa un vector de repulsion calculado
desde las lecturas de proximidad para alejarse de obstaculos de forma mas suave.

### Aggregation

`aggregation/aggregation_one.lua` implementa agregacion individualista sobre una
region negra detectada con sensores de suelo.

`aggregation/aggregation_two.lua` extiende el comportamiento a dos regiones de
interes y usa range-and-bearing para mantener senales locales de agregacion.

`aggregation/Enhancing_aggregation.lua` agrega taxis: robots en busqueda usan
senales de robots agregados para moverse hacia grupos ya formados.

### Pattern formation

Los controladores en `pattern_formation/` usan fuerzas artificiales tipo
Lennard-Jones para mantener distancias entre robots y formar patrones locales:

- `Hexagonal_pattern_formation.lua`: formacion hexagonal o triangular.
- `Circular_pattern_formation.lua`: organizacion alrededor de un LED rojo.
- `Flocking.lua`: movimiento colectivo manteniendo espaciado local.

### Foraging

`foraging/foraging_controller.lua` implementa un sistema de estados para buscar
comida, volver al nido, evitar una zona prohibida y emitir senales locales:

- `1`: robot cargando item.
- `2`: baliza de peligro.
- `3`: baliza de nido.

La loop function en C++ administra recogida, entrega y perdida de items. La
salida de rendimiento se escribe en `foraging/output.txt`, que no debe
versionarse.


## Notas para publicar cambios

Antes de hacer commit, revisa:

```bash
git status --short
```

Solo deberian aparecer archivos fuente, scripts y documentacion. No subas
`argos3/`, `argos3-dist/`, `foraging/build/`, `backups/` ni salidas generadas.

Si en el futuro quieres distribuir binarios de Ubuntu 24.04, es mejor subir un
archivo comprimido como GitHub Release, no versionarlo directamente en el repo.
Los binarios dependen de rutas, version de sistema y librerias dinamicas.
