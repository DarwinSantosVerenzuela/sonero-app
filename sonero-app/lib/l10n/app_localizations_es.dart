// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Sonero';

  @override
  String get navHome => 'Inicio';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navAnalytics => 'Estadísticas';

  @override
  String get navDownload => 'Descargar de YouTube';

  @override
  String get navSearch => 'Buscador';

  @override
  String get downloadComplete => 'Descarga Completada';

  @override
  String get librarySection => 'BIBLIOTECA';

  @override
  String get newPlaylist => 'Nueva Playlist';

  @override
  String get newPlaylistHint => 'Nombre de la playlist';

  @override
  String get create => 'Crear';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Cerrar';

  @override
  String get save => 'Guardar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get change => 'Cambiar';

  @override
  String get delete => 'Eliminar';

  @override
  String get retry => 'Reintentar';

  @override
  String get clear => 'Limpiar';

  @override
  String get open => 'Abrir';

  @override
  String get download => 'Descargar';

  @override
  String get refresh => 'Actualizar';

  @override
  String get renamePlaylist => 'Renombrar Playlist';

  @override
  String get newPlaylistName => 'Nuevo nombre';

  @override
  String get rename => 'Renombrar';

  @override
  String get deletePlaylist => 'Eliminar Playlist';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Se eliminará \"$name\". El contenido se mantendrá en tu Biblioteca.';
  }

  @override
  String get settings => 'Configuración';

  @override
  String get welcomeHome => 'Bienvenido a Sonero';

  @override
  String get play => 'Reproducir';

  @override
  String get moreInfo => 'Más información';

  @override
  String get continueWatching => 'Seguir Reproduciendo';

  @override
  String get yourSmartPlaylists => 'Playlists Inteligentes';

  @override
  String get language => 'Idioma';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageJapanese => 'Japonés';

  @override
  String get appearance => 'Apariencia';

  @override
  String get apiConnection => 'Conexión a la API (Local/Remota)';

  @override
  String get musicFolder => 'Carpeta de Medios';

  @override
  String get playerShuffle => 'Aleatorio';

  @override
  String get playerPrevious => 'Anterior';

  @override
  String get playerNext => 'Siguiente';

  @override
  String get playerRepeat => 'Repetir';

  @override
  String get playerShowVideo => 'Mostrar Video';

  @override
  String get playerGridView => 'Vista de Cuadrícula';

  @override
  String get playerListView => 'Vista de Lista';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'es',
      one: '',
    );
    return '$count canción$_temp0';
  }

  @override
  String get autoFillMetadata => 'Autocompletar Metadatos';

  @override
  String get exportCsv => 'Exportar CSV';

  @override
  String csvSaved(String path) {
    return 'CSV guardado: $path';
  }

  @override
  String get editMetadata => 'Editar metadatos';

  @override
  String get autoFillMetadataApi => 'Autocompletar metadatos (API)';

  @override
  String get deleteFile => 'Eliminar archivo';

  @override
  String get moveTo => 'Mover a...';

  @override
  String get libraryRoot => 'Biblioteca (raíz)';

  @override
  String get deleteSong => 'Eliminar canción';

  @override
  String deleteSongConfirm(String name) {
    return '¿Seguro que quieres eliminar \"$name\" del disco?';
  }

  @override
  String get fileDeleted => 'Archivo eliminado';

  @override
  String movedTo(String destination) {
    return 'Movida a $destination';
  }

  @override
  String get emptyLibrary => 'Tu biblioteca está vacía';

  @override
  String emptyPlaylist(String name) {
    return '$name está vacía';
  }

  @override
  String get emptyLibraryHint =>
      'Presiona el atajo de teclado para reconocer una canción';

  @override
  String get scanningMetadata => 'Escaneando Metadatos';

  @override
  String get startingScan => 'Iniciando escaneo...';

  @override
  String get starting => 'Iniciando...';

  @override
  String get unknownError => 'Error desconocido';

  @override
  String get analyticsTitle => 'Analíticas de Consumo';

  @override
  String get yourHabits => 'Tus Hábitos';

  @override
  String get playbackHours => 'Horas de reproducción';

  @override
  String get videosCompleted => 'Videos Completados';

  @override
  String get musicListened => 'Música Escuchada';

  @override
  String get recentHistory => 'Historial Reciente (Benrio)';

  @override
  String get analyticsPlaceholder =>
      'Aquí se integrarán los datos desde el backend cuando se implemente la conexión con Benrio.';

  @override
  String get searchHint => 'Buscar canciones, artistas, o YouTube...';

  @override
  String get typeToSearch => 'Escribe para buscar...';

  @override
  String get noLocalResults => 'No hay resultados locales';

  @override
  String localLibraryCount(int count) {
    return 'Biblioteca Local ($count)';
  }

  @override
  String get noYouTubeResults => 'No hay resultados en YouTube';

  @override
  String get downloadMedia => 'Descargar Medio';

  @override
  String get format => 'Formato:';

  @override
  String formatLoadError(String error) {
    return 'Error cargando formatos: $error';
  }

  @override
  String get destinationPlaylist => 'Destino (Playlist):';

  @override
  String get downloadYouTubeVideo => 'Descargar Video de YouTube';

  @override
  String get fetchInfo => 'Obtener Info';

  @override
  String get selectFormat => 'Seleccionar Formato:';

  @override
  String get videoFolder => 'Carpeta de Video';

  @override
  String get notSelected => 'No seleccionada';

  @override
  String get selectFolder => 'Seleccionar carpeta';

  @override
  String get selectMusicFolderDialog =>
      'Selecciona la carpeta donde guardar la música';

  @override
  String get selectVideoFolderDialog =>
      'Selecciona la carpeta donde guardar los videos';

  @override
  String get authentication => 'Autenticación (Anti-Bot)';

  @override
  String get authDescription =>
      'Usa tus cookies de YouTube para evitar bloqueos al descargar.';

  @override
  String get syncBenrio => 'Sincronizar (Benrio)';

  @override
  String get cookiesSynced => 'Cookies sincronizadas correctamente.';

  @override
  String get loadCookiesFile => 'Cargar cookies.txt';

  @override
  String get selectCookiesDialog => 'Selecciona tu archivo cookies.txt';

  @override
  String get fileLoaded => 'Archivo cargado correctamente.';

  @override
  String get themeMode => 'Modo de tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get primaryColor => 'Color principal';

  @override
  String get sidebarColor => 'Color de barra lateral';

  @override
  String get defaultColor => 'Por defecto';

  @override
  String get selectColor => 'Seleccionar color';

  @override
  String get saveUrl => 'Guardar URL';

  @override
  String get refetchTest => 'Refetch / Probar';

  @override
  String get connectionSuccess => '✅ Conexión exitosa al backend.';

  @override
  String get connectionFailed => '❌ No se pudo conectar al backend.';

  @override
  String get listenDuration => 'Duración de escucha';

  @override
  String get durationSaved => 'Duración guardada';

  @override
  String get durationRange => 'Entre 5 y 60 segundos.';

  @override
  String get secondsSuffix => 'seg';

  @override
  String get globalHotkeys => 'Atajos de teclado globales';

  @override
  String get hotkeysDescription =>
      'Funcionan aunque la ventana esté minimizada.';

  @override
  String get hotkeyMic => '🎙️ Escuchar con Micrófono';

  @override
  String get hotkeySystem => '🖥️ Escuchar Audio del Sistema';

  @override
  String get hotkeyVideo => '📺 Descargar Video (Portapapeles)';

  @override
  String get hotkeyShow => '👀 Mostrar Ventana';

  @override
  String get hotkeyHide => '👻 Ocultar Ventana';

  @override
  String get hotkeySaved => 'Atajo guardado';

  @override
  String get hotkeyTitleMic => '🎙️ Atajo — Micrófono';

  @override
  String get hotkeyTitleSystem => '🖥️ Atajo — Sistema';

  @override
  String get hotkeyTitleVideo => '📺 Atajo — Video';

  @override
  String get hotkeyTitleShow => '👀 Atajo — Mostrar Ventana';

  @override
  String get hotkeyTitleHide => '👻 Atajo — Ocultar Ventana';

  @override
  String get hotkeyRecordPrompt =>
      'Presiona la combinación de teclas que quieres usar.';

  @override
  String get micDevice => 'Dispositivo de micrófono';

  @override
  String deviceNumber(int index) {
    return 'Dispositivo #$index';
  }

  @override
  String get systemDefault => 'Default del sistema';

  @override
  String get detectDevices => 'Detectar dispositivos';

  @override
  String get useDefault => 'Usar default';

  @override
  String get audioDevices => 'Dispositivos de audio';

  @override
  String get editMetadataTitle => 'Editar Metadatos';

  @override
  String get fieldTitle => 'Título';

  @override
  String get fieldArtist => 'Artista';

  @override
  String get fieldAlbum => 'Álbum';

  @override
  String get fieldYear => 'Año';

  @override
  String get fieldGenre => 'Género';

  @override
  String errorSaving(String error) {
    return 'Error guardando: $error';
  }

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get playlistDetected => 'Playlist de YouTube detectada';

  @override
  String get downloadPlaylist => 'Descargar Playlist';

  @override
  String get playlistDownloadOptions => 'Opciones de descarga de Playlist';

  @override
  String get loadingPlaylistInfo => 'Cargando información de la playlist...';

  @override
  String playlistVideosCount(int count) {
    return '$count videos encontrados';
  }

  @override
  String enqueuingDownloads(int count) {
    return 'Encolando $count descargas...';
  }

  @override
  String playlistEnqueued(int count) {
    return 'Se han encolado $count descargas en el gestor.';
  }
}
