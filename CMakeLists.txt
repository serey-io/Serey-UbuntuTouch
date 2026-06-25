cmake_minimum_required(VERSION 3.16)
project(serey)

# Pure-QML app: no compilation. We configure the manifest with the framework /
# architecture supplied by Clickable, then install the QML, assets and hooks
# into the click package root.

set(QT_IMPORTS_DIR "lib/${CMAKE_LIBRARY_ARCHITECTURE}")

set(APP_NAME serey)
set(DESKTOP_FILE "${APP_NAME}.desktop")
set(ICON_FILE assets/serey-logo.png)

# Fill @CLICK_FRAMEWORK@ / $ENV{...} placeholders in manifest.json.in -> manifest.json
configure_file(manifest.json.in ${CMAKE_CURRENT_BINARY_DIR}/manifest.json)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/manifest.json
    DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES ${APP_NAME}.apparmor
    DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES ${DESKTOP_FILE}
    DESTINATION ${CMAKE_INSTALL_PREFIX})

install(DIRECTORY qml
    DESTINATION ${CMAKE_INSTALL_PREFIX})
install(DIRECTORY assets
    DESTINATION ${CMAKE_INSTALL_PREFIX})

# Translations
add_subdirectory(po)
