const LANGS_ON_SITE = "日本語, 中文, English, Español, Português, Русский";

const COPY = {
  ru: {
    navMap: "Карта",
    navGet: "Скачать",
    kicker: "для Mac",
    title: "Insula",
    lede: "Она сидит у выреза камеры и показывает, что сейчас активно — музыку или таймер, — без необходимости её открывать.",
    download: "Скачать для Mac",
    win: "Windows — в планах",
    hover: "наведите на Insula",
    lidNotch: "с челкой",
    lidNone: "без челки",
    mapTitle: "Что на Insula",
    mapLede: "Нажмите фишку на Insula — справа коротко, что она делает.",
    mapHint: "Выбрано",
    timer: "Таймер",
    timerHow: "Слева: часы, минуты, секунды. По окончании — звук и уведомление; музыка, если играла, ставится на паузу, а потом снова включается.",
    edit: "Редакт",
    editHow: "Нажмите на значок карандаша справа, рядом с вырезом, чтобы войти в режим редактирования. Нажмите ещё раз или на «Готово», чтобы выйти.",
    guide: "Гайд",
    guideHow: "Кнопка находится рядом с карандашом. Нажмите, чтобы начать сначала. Пока тур идёт, то же нажатие его закрывает.",
    mic: "Мьют",
    micHow: "Нажатие сразу выключает микрофон Mac для всех приложений. Обычный белый значок микрофона — вас слышно. Красный значок на белом фоне — вы выключены.",
    clipboard: "Буфер",
    clipboardHow: "Значок буфера обмена справа. Нажмите на него, чтобы увидеть последние скопированные фрагменты, и на любой из них — чтобы скопировать снова.",
    media: "Медиа",
    mediaHow: "Они расположены под вырезом камеры. Нажмите на обложку, чтобы открыть полноценный плеер. Назад, пауза, вперёд. Если в режиме редактирования включены анимации, кнопки паузы и перемотки подсвечиваются при использовании.",
    lyrics: "Субтитры",
    lyricsHow: "Нажмите на значок в виде облачка рядом с кнопками воспроизведения. Если для текущей песни текста нет, кнопка скрыта или неактивна.",
    playlist: "Плейлист",
    playlistHow: "Значок списка появляется, только если Music поделился текущим плейлистом. Нажмите на него, чтобы открыть окно со всей очередью; играющий сейчас трек подсвечен.",
    progress: "Прогресс",
    progressHow: "Полоса прогресса находится под кнопками управления на развёрнутой Insula. Потяните её, чтобы перейти к другому моменту песни.",
    anim: "Анимации",
    animHow: "В режиме редактирования нажмите на кнопку на Insula, чтобы отправить её в лоток снизу. Нажмите на плитку в лотке, чтобы вернуть кнопку обратно. Значок-искра включает или выключает подсветку паузы и перемотки. «Готово» завершает редактирование.",
    hoverWhy: "Insula не должна раскрываться от любого движения курсора рядом с камерой — но и не должна «тормозить», когда она правда нужна.",
    hoverBody: "Быстрый проход мимо не откроет её — задержите курсор примерно на 0.1 секунды. При медленном приближении сначала появляется узкая щель, а полностью Insula раскрывается только в верхней трети, у самой камеры.",
    moveWhy: "Insula можно перенести в другое место на экране.",
    moveBody: "Кликните по нему три раза подряд быстро, в течение примерно полутора секунд, — и она начнёт следовать за курсором. После тройного клика подождите около двух секунд и кликните один раз — Insula по прямой полетит к ближайшему краю. Внизу она становится пилюлей, сбоку — карточкой. Найдите маленькую иконку домика рядом с вырезом. Один клик — и Insula дома.",
    moveTitle: "Перенос",
    moveLede: "Кликните по нему три раза подряд быстро, в течение примерно полутора секунд, — и она начнёт следовать за курсором. После тройного клика подождите около двух секунд и кликните один раз — Insula по прямой полетит к ближайшему краю. Внизу она становится пилюлей, сбоку — карточкой. Найдите маленькую иконку домика рядом с вырезом. Один клик — и Insula дома.",
    moveHouse: "домой",
    moveSide: "сбоку",
    moveBottom: "снизу",
    moveClicks: "три клика",
    micWhy: "В Zoom, Discord и любом другом приложении своя отдельная кнопка mute — легко забыть, где она включена.",
    micBody: "Нажатие сразу выключает микрофон Mac для всех приложений. Обычный белый значок микрофона — вас слышно. Красный значок на белом фоне — вы выключены.",
    lyricsWhy: "Текст песни не помещается в Insula, поэтому он открывается рядом, в отдельном окне.",
    lyricsBody: "Нажмите на значок в виде облачка рядом с кнопками воспроизведения. Если для текущей песни текста нет, кнопка скрыта или неактивна. Это полупрозрачная панель со своей кнопкой закрытия — её можно перетаскивать по экрану. Музыка при этом продолжает играть.",
    lyricsTitle: "Субтитры",
    lyricsLede: "Текст песни читают рядом с Insula, а не внутри маленькой капсулы. Это полупрозрачная панель со своей кнопкой закрытия — её можно перетаскивать по экрану. Музыка при этом продолжает играть.",
    lyricsGrab: "тянуть здесь",
    lyricsCorner: "угол — размер",
    editWhy: "Не всем нужны все кнопки сразу. Лишние необязательно держать на капсуле.",
    editBody: "Нажмите на значок карандаша справа, рядом с вырезом, чтобы войти в режим редактирования. Нажмите ещё раз или на «Готово», чтобы выйти.",
    editTitle: "Редакт",
    editLede: "Нажмите на значок карандаша справа, рядом с вырезом, чтобы войти в режим редактирования. Нажмите ещё раз или на «Готово», чтобы выйти. В режиме редактирования нажмите на кнопку на Insula, чтобы отправить её в лоток снизу. Нажмите на плитку в лотке, чтобы вернуть кнопку обратно. Значок-искра включает или выключает подсветку паузы и перемотки. «Готово» завершает редактирование.",
    editTrayLab: "лоток",
    getTitle: "Бесплатно на Mac",
    getBody: "macOS 14 и новее, Apple Silicon (M1 и новее). Не из App Store. После установки: правый клик по Insula → «Открыть» (двойной клик система часто блокирует).",
    reqs: "Обложка и кнопки трека — из Music или Spotify.",
    donate: "Донат появится здесь, когда будет ссылка.",
    partner: "Партнёрство — без формы на этой странице.",
    privacy: "Политика",
    missing: "Файл сборки ещё не лежит в downloads/Insula.dmg.",
    song: "Night Harbor",
    artist: "Local",
    allOn: "Всё на Insula",
    done: "Done",
    playAnim: "Смотреть",
    playAgain: "Ещё раз",
  },
  en: {
    navMap: "Map",
    navGet: "Download",
    kicker: "for Mac",
    title: "Insula",
    lede: "It sits over the camera and shows what's active — music or a timer — without you opening it.",
    download: "Download for Mac",
    win: "Windows — planned",
    hover: "hover Insula",
    lidNotch: "with notch",
    lidNone: "no notch",
    mapTitle: "What’s on Insula",
    mapLede: "Tap a chip on Insula — on the right, a short note about what it does.",
    mapHint: "Selected",
    timer: "Timer",
    timerHow: "On the left side: hours, minutes, seconds. When it ends you get a sound and a notification; any music playing pauses, then resumes.",
    edit: "Edit",
    editHow: "Tap the pencil icon on the right side, near the notch, to enter edit mode. Tap it again, or tap Done, to leave.",
    guide: "Guide",
    guideHow: "The button sits next to the pencil. Tap it to start over from the beginning. While the tour is running, the same tap closes it.",
    mic: "Mute",
    micHow: "Tap this to mute your Mac's microphone for every app at once. A plain white mic icon means people can hear you. A red mic on white means you're muted.",
    clipboard: "Clipboard",
    clipboardHow: "The clipboard icon is on the right side. Tap it to see recent copies, then tap any entry to copy it again.",
    media: "Media",
    mediaHow: "They sit below the notch. Tap the artwork to open the full player. Back, pause, and next. If animations are turned on in edit mode, pause and skip glow when you use them.",
    lyrics: "Lyrics",
    lyricsHow: "Tap the speech-bubble icon next to the playback controls. If there are no lyrics for the current song, the button is hidden or does nothing.",
    playlist: "Playlist",
    playlistHow: "The list icon only appears if Music shares its current playlist. Tap it to open a window with the full queue; the current track is highlighted.",
    progress: "Progress",
    progressHow: "The bar sits below the controls on the full-size Insula. Drag it to jump to a different point in the song.",
    anim: "Animations",
    animHow: "In edit mode, tap a button on Insula to send it to the tray below. Tap a tile in the tray to bring it back. The sparkle icon turns the pause/skip glow animation on or off. Tap Done to leave edit mode.",
    hoverWhy: "Insula shouldn't pop open every time your cursor passes near the camera, but it shouldn't feel slow either when you actually want it.",
    hoverBody: "A quick pass-by won't open it — pause on it for about 0.1 seconds. Moving in slowly shows the small gap first, then opens the full Insula near the top, right by the camera.",
    moveWhy: "You can move Insula to a different spot on the screen.",
    moveBody: "Click it three times quickly, within about a second and a half, and it starts following your cursor. After the triple-click, wait about two seconds, then click once — it slides straight to the nearest edge. At the bottom it becomes a pill; on the side, a card. Look for the small house icon near the notch. One click and it's back home.",
    moveTitle: "Move",
    moveLede: "Click it three times quickly, within about a second and a half, and it starts following your cursor. After the triple-click, wait about two seconds, then click once — it slides straight to the nearest edge. At the bottom it becomes a pill; on the side, a card. Look for the small house icon near the notch. One click and it's back home.",
    moveHouse: "home",
    moveSide: "side",
    moveBottom: "bottom",
    moveClicks: "three clicks",
    micWhy: "Zoom, Discord, and every other app has its own separate mute button — easy to lose track of which one is on.",
    micBody: "Tap this to mute your Mac's microphone for every app at once. A plain white mic icon means people can hear you. A red mic on white means you're muted.",
    lyricsWhy: "Lyrics don't fit inside Insula, so they open in a separate space next to it.",
    lyricsBody: "Tap the speech-bubble icon next to the playback controls. If there are no lyrics for the current song, the button is hidden or does nothing. It's a translucent panel with its own close button, and you can drag it anywhere on screen. Music keeps playing while it's open.",
    lyricsTitle: "Lyrics",
    lyricsLede: "Lyrics are read next to Insula, not squeezed inside the small capsule. It's a translucent panel with its own close button, and you can drag it anywhere on screen. Music keeps playing while it's open.",
    lyricsGrab: "drag here",
    lyricsCorner: "corner — size",
    editWhy: "Not everyone needs every button. Anything extra doesn't have to stay on the capsule.",
    editBody: "Tap the pencil icon on the right side, near the notch, to enter edit mode. Tap it again, or tap Done, to leave.",
    editTitle: "Edit",
    editLede: "Tap the pencil icon on the right side, near the notch, to enter edit mode. Tap it again, or tap Done, to leave. In edit mode, tap a button on Insula to send it to the tray below. Tap a tile in the tray to bring it back. The sparkle icon turns the pause/skip glow animation on or off. Tap Done to leave edit mode.",
    editTrayLab: "tray",
    getTitle: "Free on Mac",
    getBody: "macOS 14 and later. Not the App Store — a disk image. After download: right-click → Open if the system asks.",
    reqs: "Artwork and track buttons come from Music or Spotify.",
    donate: "A donate link will sit here when there is one.",
    partner: "Partnership — no form on this page.",
    privacy: "Privacy",
    missing: "The build is not in downloads/Insula.dmg yet.",
    song: "Night Harbor",
    artist: "Local",
    allOn: "All on Insula",
    done: "Done",
    playAnim: "Watch",
    playAgain: "Watch again",
  },
  es: {
    navMap: "Mapa",
    navGet: "Descargar",
    kicker: "para Mac",
    title: "Insula",
    lede: "Se coloca sobre la cámara y muestra lo que está activo —música o un temporizador— sin que tengas que abrirla.",
    download: "Descargar para Mac",
    win: "Windows — en planes",
    hover: "pasa el cursor por Insula",
    lidNotch: "con recorte",
    lidNone: "sin recorte",
    mapTitle: "Qué hay en Insula",
    mapLede: "Toca una ficha en Insula: a la derecha, una nota corta de lo que hace.",
    mapHint: "Elegido",
    timer: "Temporizador",
    timerHow: "A la izquierda: horas, minutos y segundos. Al terminar suena un aviso y llega una notificación; si había música sonando, se pausa y luego sigue.",
    edit: "Editar",
    editHow: "Toca el icono del lápiz a la derecha, junto al recorte, para entrar en modo edición. Tócalo otra vez, o toca «Listo», para salir.",
    guide: "Guía",
    guideHow: "El botón está junto al lápiz. Tócalo para empezar de nuevo desde el principio. Mientras el recorrido está en marcha, el mismo toque lo cierra.",
    mic: "Mute",
    micHow: "Tócalo para silenciar el micrófono del Mac en todas las apps a la vez. Un icono de micrófono blanco significa que se te oye. Uno rojo sobre blanco significa que estás silenciado.",
    clipboard: "Portapapeles",
    clipboardHow: "El icono del portapapeles está a la derecha. Tócalo para ver lo copiado recientemente, y toca cualquier entrada para copiarla de nuevo.",
    media: "Medios",
    mediaHow: "Aparecen debajo del recorte. Toca la carátula para abrir el reproductor completo. Atrás, pausa y siguiente. Si las animaciones están activadas en modo edición, pausa y siguiente se iluminan al usarlos.",
    lyrics: "Subtítulos",
    lyricsHow: "Toca el icono del globo de texto junto a los controles de reproducción. Si la canción no tiene letra disponible, el botón queda oculto o no responde.",
    playlist: "Lista",
    playlistHow: "El icono de lista solo aparece si Music comparte la lista de reproducción actual. Tócalo para abrir una ventana con toda la cola; el tema actual queda resaltado.",
    progress: "Progreso",
    progressHow: "La barra está debajo de los controles, en Insula grande. Arrástrala para saltar a otro punto de la canción.",
    anim: "Animaciones",
    animHow: "En modo edición, toca un botón de Insula para mandarlo a la bandeja de abajo. Toca una ficha de la bandeja para devolverlo. El icono de chispa activa o desactiva la animación de pausa y salto. Toca «Listo» para salir del modo edición.",
    hoverWhy: "Insula no debería abrirse cada vez que el cursor pasa cerca de la cámara, pero tampoco debería sentirse lenta cuando de verdad la quieres usar.",
    hoverBody: "Un simple paso rápido no la abre: quédate sobre ella unos 0,1 segundos. Si te acercas despacio, primero aparece el hueco pequeño y luego se abre del todo, cerca de la parte superior, junto a la cámara.",
    moveWhy: "Puedes mover Insula a otro punto de la pantalla.",
    moveBody: "Haz tres clics rápidos seguidos, en poco más de un segundo, y empezará a seguir al cursor. Después del triple clic, espera unos dos segundos y haz un clic más: se desliza en línea recta hasta el borde más cercano. Abajo se convierte en píldora; al lado, en tarjeta. Busca el pequeño icono de casa junto al recorte. Un clic y vuelve a su sitio.",
    moveTitle: "Mover",
    moveLede: "Haz tres clics rápidos seguidos, en poco más de un segundo, y empezará a seguir al cursor. Después del triple clic, espera unos dos segundos y haz un clic más: se desliza en línea recta hasta el borde más cercano. Abajo se convierte en píldora; al lado, en tarjeta. Busca el pequeño icono de casa junto al recorte. Un clic y vuelve a su sitio.",
    moveHouse: "inicio",
    moveSide: "al lado",
    moveBottom: "abajo",
    moveClicks: "tres clics",
    micWhy: "Zoom, Discord y cualquier otra app tienen su propio botón de silencio, y es fácil perder de vista cuál está activado.",
    micBody: "Tócalo para silenciar el micrófono del Mac en todas las apps a la vez. Un icono de micrófono blanco significa que se te oye. Uno rojo sobre blanco significa que estás silenciado.",
    lyricsWhy: "La letra no cabe dentro de Insula, así que se abre aparte, al lado.",
    lyricsBody: "Toca el icono del globo de texto junto a los controles de reproducción. Si la canción no tiene letra disponible, el botón queda oculto o no responde. Es un panel translúcido con su propio botón de cerrar, y puedes arrastrarlo a cualquier parte de la pantalla. La música sigue sonando mientras está abierto.",
    lyricsTitle: "Letra",
    lyricsLede: "La letra se lee al lado de Insula, no metida dentro de la cápsula pequeña. Es un panel translúcido con su propio botón de cerrar, y puedes arrastrarlo a cualquier parte de la pantalla. La música sigue sonando mientras está abierto.",
    lyricsGrab: "arrastrar aquí",
    lyricsCorner: "esquina — tamaño",
    editWhy: "No todo el mundo necesita todos los botones. Lo que sobra no tiene por qué quedarse en la cápsula.",
    editBody: "Toca el icono del lápiz a la derecha, junto al recorte, para entrar en modo edición. Tócalo otra vez, o toca «Listo», para salir.",
    editTitle: "Editar",
    editLede: "Toca el icono del lápiz a la derecha, junto al recorte, para entrar en modo edición. Tócalo otra vez, o toca «Listo», para salir. En modo edición, toca un botón de Insula para mandarlo a la bandeja de abajo. Toca una ficha de la bandeja para devolverlo. El icono de chispa activa o desactiva la animación de pausa y salto. Toca «Listo» para salir del modo edición.",
    editTrayLab: "bandeja",
    getTitle: "Gratis en Mac",
    getBody: "macOS 14 o posterior. No es el App Store: una imagen de disco. Tras bajar: clic derecho → Abrir si el sistema pregunta.",
    reqs: "La carátula y los botones del tema salen de Music o Spotify.",
    donate: "El enlace de donar estará aquí cuando exista.",
    partner: "Colaboración — no hay formulario en esta página.",
    privacy: "Privacidad",
    missing: "El archivo aún no está en downloads/Insula.dmg.",
    song: "Night Harbor",
    artist: "Local",
    allOn: "Todo en Insula",
    done: "Done",
    playAnim: "Ver",
    playAgain: "Ver otra vez",
  },
  pt: {
    navMap: "Mapa",
    navGet: "Baixar",
    kicker: "para Mac",
    title: "Insula",
    lede: "Ela fica sobre a câmera e mostra o que está ativo — música ou um temporizador — sem que você precise abri-la.",
    download: "Baixar para Mac",
    win: "Windows — nos planos",
    hover: "passe o cursor sobre a Insula",
    lidNotch: "com recorte",
    lidNone: "sem recorte",
    mapTitle: "O que há na Insula",
    mapLede: "Toque num chip na Insula — à direita, uma nota curta do que faz.",
    mapHint: "Selecionado",
    timer: "Temporizador",
    timerHow: "Do lado esquerdo: horas, minutos, segundos. Quando termina, toca um som e chega uma notificação; se havia música tocando, ela pausa e depois volta.",
    edit: "Editar",
    editHow: "Toque no ícone do lápis à direita, perto do recorte, para entrar no modo de edição. Toque de novo, ou toque em «Concluir», para sair.",
    guide: "Guia",
    guideHow: "O botão fica ao lado do lápis. Toque para começar de novo, do início. Enquanto o tour está rodando, o mesmo toque o fecha.",
    mic: "Mudo",
    micHow: "Toque aqui para silenciar o microfone do Mac em todos os apps de uma vez. Um ícone de microfone branco simples significa que dá para te ouvir. Um microfone vermelho sobre fundo branco significa que você está mudo.",
    clipboard: "Área de transferência",
    clipboardHow: "O ícone da área de transferência fica à direita. Toque nele para ver o que foi copiado recentemente, e toque em qualquer item para copiá-lo de novo.",
    media: "Mídia",
    mediaHow: "Eles ficam embaixo do recorte. Toque na capa para abrir o player completo. Voltar, pausar e avançar. Se as animações estiverem ativadas no modo de edição, pausar e pular acendem quando usados.",
    lyrics: "Legendas",
    lyricsHow: "Toque no ícone de balão de fala ao lado dos controles de reprodução. Se a música não tiver letra disponível, o botão fica escondido ou não faz nada.",
    playlist: "Playlist",
    playlistHow: "O ícone de lista só aparece se o Music estiver compartilhando a playlist atual. Toque nele para abrir uma janela com a fila inteira; a faixa atual fica destacada.",
    progress: "Progresso",
    progressHow: "A barra fica abaixo dos controles, na Insula grande. Arraste-a para pular para outro ponto da música.",
    anim: "Animações",
    animHow: "No modo de edição, toque em um botão da Insula para mandá-lo para a bandeja abaixo. Toque em um item da bandeja para trazê-lo de volta. O ícone de brilho liga ou desliga a animação de pausa/pular. Toque em «Concluir» para sair do modo de edição.",
    hoverWhy: "Insula não deveria se abrir toda vez que o cursor passa perto da câmera, mas também não deveria demorar quando você realmente quer usá-la.",
    hoverBody: "Só passar rápido por cima não abre Insula — fique parado nela por cerca de 0,1 segundo. Chegando devagar, primeiro aparece a fenda pequena, e Insula só abre por completo perto do topo, junto à câmera.",
    moveWhy: "Você pode mover Insula para outro lugar da tela.",
    moveBody: "Clique nela três vezes rápido, em cerca de um segundo e meio, e ela passa a seguir o cursor. Depois do triplo clique, espere uns dois segundos e clique mais uma vez — ela desliza em linha reta até a borda mais próxima. Embaixo vira uma pílula; do lado, um cartão. Procure o pequeno ícone de casa perto do recorte. Um clique e ela volta para o lugar.",
    moveTitle: "Mover",
    moveLede: "Clique nela três vezes rápido, em cerca de um segundo e meio, e ela passa a seguir o cursor. Depois do triplo clique, espere uns dois segundos e clique mais uma vez — ela desliza em linha reta até a borda mais próxima. Embaixo vira uma pílula; do lado, um cartão. Procure o pequeno ícone de casa perto do recorte. Um clique e ela volta para o lugar.",
    moveHouse: "início",
    moveSide: "do lado",
    moveBottom: "embaixo",
    moveClicks: "três cliques",
    micWhy: "Zoom, Discord e qualquer outro app têm seu próprio botão de mudo, e é fácil perder de vista qual está ativado.",
    micBody: "Toque aqui para silenciar o microfone do Mac em todos os apps de uma vez. Um ícone de microfone branco simples significa que dá para te ouvir. Um microfone vermelho sobre fundo branco significa que você está mudo.",
    lyricsWhy: "A letra não cabe dentro da Insula, então ela abre à parte, ao lado.",
    lyricsBody: "Toque no ícone de balão de fala ao lado dos controles de reprodução. Se a música não tiver letra disponível, o botão fica escondido ou não faz nada. É um painel translúcido com seu próprio botão de fechar, e dá para arrastá-lo para qualquer lugar da tela. A música continua tocando enquanto ele está aberto.",
    lyricsTitle: "Letra",
    lyricsLede: "A letra é lida ao lado da Insula, não espremida dentro da cápsula pequena. É um painel translúcido com seu próprio botão de fechar, e dá para arrastá-lo para qualquer lugar da tela. A música continua tocando enquanto ele está aberto.",
    lyricsGrab: "arrastar aqui",
    lyricsCorner: "canto — tamanho",
    editWhy: "Nem todo mundo precisa de todos os botões. O que sobra não precisa ficar na cápsula.",
    editBody: "Toque no ícone do lápis à direita, perto do recorte, para entrar no modo de edição. Toque de novo, ou toque em «Concluir», para sair.",
    editTitle: "Editar",
    editLede: "Toque no ícone do lápis à direita, perto do recorte, para entrar no modo de edição. Toque de novo, ou toque em «Concluir», para sair. No modo de edição, toque em um botão da Insula para mandá-lo para a bandeja abaixo. Toque em um item da bandeja para trazê-lo de volta. O ícone de brilho liga ou desliga a animação de pausa/pular. Toque em «Concluir» para sair do modo de edição.",
    editTrayLab: "bandeja",
    getTitle: "Grátis no Mac",
    getBody: "macOS 14 ou posterior. Não é a App Store: uma imagem de disco. Depois de baixar: clique com o botão direito → Abrir se o sistema perguntar.",
    reqs: "Capa e botões da faixa vêm do Music ou Spotify.",
    donate: "O link de doação fica aqui quando existir.",
    partner: "Parceria — sem formulário nesta página.",
    privacy: "Privacidade",
    missing: "O arquivo ainda não está em downloads/Insula.dmg.",
    song: "Night Harbor",
    artist: "Local",
    allOn: "Tudo na Insula",
    done: "Done",
    playAnim: "Ver",
    playAgain: "Ver de novo",
  },
  zh: {
    navMap: "地图",
    navGet: "下载",
    kicker: "适用于 Mac",
    title: "岛",
    lede: "它贴在摄像头位置，会显示当前有什么在活动——比如音乐或计时器——不需要你把它展开。",
    download: "下载 Mac 版",
    win: "Windows — 计划中",
    hover: "将光标移到 Insula 上",
    lidNotch: "有刘海",
    lidNone: "无刘海",
    mapTitle: "Insula 上有什么",
    mapLede: "点 Insula 上的功能点，右侧会简短说明它做什么。",
    mapHint: "已选",
    timer: "计时器",
    timerHow: "左侧可以设置小时、分钟、秒。倒计时结束时会有声音提示和系统通知；如果正在播放音乐，会先暂停再继续播放。",
    edit: "编辑",
    editHow: "点右侧靠近刘海的铅笔图标，进入编辑模式。再点一次，或者点「完成」，即可退出。",
    guide: "指南",
    guideHow: "按钮就在铅笔图标旁边。点一下从头开始播放导览；导览进行中再点同一个按钮会直接关闭它。",
    mic: "静音",
    micHow: "点一下就能一次性把 Mac 麦克风对所有 App 静音。普通白色麦克风图标表示对方能听到你；白底红色图标表示你已静音。",
    clipboard: "剪贴板",
    clipboardHow: "剪贴板图标在右侧。点开可以看到最近复制的内容，点其中任意一条即可重新复制它。",
    media: "媒体",
    mediaHow: "它们显示在刘海下方。点封面图可以打开完整的播放器界面。 上一首、暂停、下一首。如果在编辑模式里打开了动画效果，使用暂停和切歌时按钮会有发光提示。",
    lyrics: "字幕",
    lyricsHow: "点播放按钮旁边的气泡图标。如果当前歌曲没有歌词，这个按钮会隐藏或点了没反应。",
    playlist: "播放列表",
    playlistHow: "只有当“音乐”App 提供了当前播放列表时，列表图标才会出现。点开会显示整个播放队列的窗口，正在播放的曲目会高亮显示。",
    progress: "进度",
    progressHow: "进度条在Insula展开后位于控制按钮下方。拖动它可以跳到歌曲的其他位置。",
    anim: "动画",
    animHow: "编辑模式下，点Insula 上的按钮可以把它送进下面的托盘；点托盘里的按钮可以把它放回去。星光图标用来开关暂停/切歌的发光动画。点「完成」退出编辑模式。",
    hoverWhy: "Insula 不应该因为光标随便经过摄像头附近就弹开，但真正想用它时也不能反应慢。",
    hoverBody: "快速经过不会展开它——需要在上面停留大约 0.1 秒。慢慢靠近时，先出现一条小缝，然后才会在最上方、摄像头旁边完全展开。",
    moveWhy: "你可以把 Insula移动到屏幕上的其他位置。",
    moveBody: "在大约一秒半内连续快速点击三次，Insula 就会开始跟着光标移动。 三连击之后，等大约两秒，再点一下——Insula 会沿直线滑到最近的边缘。停在底部时是胶囊形状，停在侧边时是卡片形状。 在刘海旁边找一个小房子图标。点一下，Insula 就回到原位了。",
    moveTitle: "移动",
    moveLede: "在大约一秒半内连续快速点击三次，Insula 就会开始跟着光标移动。 三连击之后，等大约两秒，再点一下——Insula 会沿直线滑到最近的边缘。停在底部时是胶囊形状，停在侧边时是卡片形状。 在刘海旁边找一个小房子图标。点一下，Insula 就回到原位了。",
    moveHouse: "主页",
    moveSide: "侧面",
    moveBottom: "底部",
    moveClicks: "点三次",
    micWhy: "Zoom、Discord 等每个 App 都有自己独立的静音按钮，很容易记不清哪个开着。",
    micBody: "点一下就能一次性把 Mac 麦克风对所有 App 静音。普通白色麦克风图标表示对方能听到你；白底红色图标表示你已静音。",
    lyricsWhy: "歌词放不进Insula 里，所以会在旁边单独打开一块区域显示。",
    lyricsBody: "点播放按钮旁边的气泡图标。如果当前歌曲没有歌词，这个按钮会隐藏或点了没反应。 这是一个半透明面板，有自己的关闭按钮，可以拖到屏幕任意位置。打开它时音乐会继续播放。",
    lyricsTitle: "歌词",
    lyricsLede: "歌词是在Insula 旁边单独阅读的，不是挤在小胶囊里面。 这是一个半透明面板，有自己的关闭按钮，可以拖到屏幕任意位置。打开它时音乐会继续播放。",
    lyricsGrab: "从这里拖",
    lyricsCorner: "角落 — 大小",
    editWhy: "不是所有人都需要用到全部按钮，用不到的完全可以从胶囊上拿掉。",
    editBody: "点右侧靠近刘海的铅笔图标，进入编辑模式。再点一次，或者点「完成」，即可退出。",
    editTitle: "编辑",
    editLede: "点右侧靠近刘海的铅笔图标，进入编辑模式。再点一次，或者点「完成」，即可退出。 编辑模式下，点Insula 上的按钮可以把它送进下面的托盘；点托盘里的按钮可以把它放回去。星光图标用来开关暂停/切歌的发光动画。点「完成」退出编辑模式。",
    editTrayLab: "托盘",
    getTitle: "Mac 上免费",
    getBody: "macOS 14 及更新。不是 App Store，是磁盘映像。下载后若系统询问：右键 → 打开。",
    reqs: "封面和切歌来自 Music 或 Spotify。",
    donate: "有捐赠链接时会放在这里。",
    partner: "合作——本页没有表格。",
    privacy: "隐私",
    missing: "安装包还没有放到 downloads/Insula.dmg。",
    song: "Night Harbor",
    artist: "Local",
    allOn: "都在 Insula 上",
    done: "Done",
    playAnim: "观看",
    playAgain: "再看一次",
  },
  ja: {
    navMap: "地図",
    navGet: "ダウンロード",
    kicker: "Mac向け",
    title: "Insula",
    lede: "カメラの位置に表示され、開かなくても音楽やタイマーなど今動いているものがわかります。",
    download: "Mac用を入手",
    win: "Windows — 予定",
    hover: "Insula にポインタを合わせる",
    lidNotch: "ノッチあり",
    lidNone: "ノッチなし",
    mapTitle: "Insula の中身",
    mapLede: "Insula のチップを押すと、右側に短い説明が出ます。",
    mapHint: "選択中",
    timer: "タイマー",
    timerHow: "左側で時・分・秒を設定します。終了すると音と通知が鳴り、再生中の音楽は一時停止したあと再び再生されます。",
    edit: "編集",
    editHow: "切り欠き近くの右側にある鉛筆アイコンをタップすると編集モードに入ります。もう一度タップするか「完了」をタップすると終了します。",
    guide: "ガイド",
    guideHow: "ボタンは鉛筆アイコンの隣にあります。タップすると最初からやり直せます。ツアー中に同じボタンをタップすると閉じます。",
    mic: "ミュート",
    micHow: "タップすると Mac のマイクをすべてのアプリに対して一括でミュートできます。白いマイクのアイコンは相手に聞こえている状態、白地に赤いマイクはミュート中を示します。",
    clipboard: "クリップボード",
    clipboardHow: "クリップボードのアイコンは右側にあります。タップすると最近コピーした内容が一覧表示され、好きな項目をタップするともう一度コピーできます。",
    media: "メディア",
    mediaHow: "切り欠きの下に表示されます。アートワークをタップするとフルプレーヤーが開きます。 戻る・一時停止・次へ、の3つです。編集モードでアニメーションをオンにしていると、一時停止とスキップのボタンが操作時に光ります。",
    lyrics: "字幕",
    lyricsHow: "再生コントロールの隣にある吹き出しアイコンをタップします。その曲に歌詞がない場合、ボタンは非表示になるか反応しません。",
    playlist: "プレイリスト",
    playlistHow: "リストアイコンは、ミュージックが現在のプレイリスト情報を渡しているときだけ表示されます。タップするとキュー全体のウィンドウが開き、再生中の曲がハイライトされます。",
    progress: "進行",
    progressHow: "バーは大きく展開した Insula の、コントロールの下にあります。ドラッグすると曲の別の位置に移動できます。",
    anim: "アニメーション",
    animHow: "編集モード中に Insula 上のボタンをタップするとトレイへ送られます。トレイのタイルをタップすると元に戻せます。キラキラのアイコンは一時停止・スキップの発光アニメーションのオン/オフ切り替えです。「完了」をタップすると編集モードを終了します。",
    hoverWhy: "カメラ付近をカーソルが通っただけで毎回開いてしまうのも、逆に本当に開きたいときに反応が遅いのも困ります。",
    hoverBody: "サッと通り過ぎただけでは開きません。約0.1秒とどまる必要があります。ゆっくり近づくと、まず小さな隙間が現れ、カメラのすぐそば・上部三分の一の範囲でだけ完全に開きます。",
    moveWhy: "Insula は画面の別の場所に動かすことができます。",
    moveBody: "約1.5秒以内に素早く3回クリックすると、カーソルについてくるようになります。 3回クリックしたあと約2秒待ってからもう1回クリックすると、最も近い端まで一直線に移動します。下端ではピル形に、側面ではカード形になります。 切り欠きの近くにある小さな家のアイコンを探してください。1回クリックするだけで元の位置に戻ります。",
    moveTitle: "移動",
    moveLede: "約1.5秒以内に素早く3回クリックすると、カーソルについてくるようになります。 3回クリックしたあと約2秒待ってからもう1回クリックすると、最も近い端まで一直線に移動します。下端ではピル形に、側面ではカード形になります。 切り欠きの近くにある小さな家のアイコンを探してください。1回クリックするだけで元の位置に戻ります。",
    moveHouse: "ホーム",
    moveSide: "横",
    moveBottom: "下",
    moveClicks: "三回クリック",
    micWhy: "Zoom や Discord など、アプリごとに別々のミュートボタンがあり、どれがオンになっているか忘れがちです。",
    micBody: "タップすると Mac のマイクをすべてのアプリに対して一括でミュートできます。白いマイクのアイコンは相手に聞こえている状態、白地に赤いマイクはミュート中を示します。",
    lyricsWhy: "歌詞は Insula の中に収まらないため、隣に別のスペースで開きます。",
    lyricsBody: "再生コントロールの隣にある吹き出しアイコンをタップします。その曲に歌詞がない場合、ボタンは非表示になるか反応しません。 半透明のパネルで、専用の閉じるボタンがあり、画面上の好きな場所にドラッグできます。開いている間も音楽は再生され続けます。",
    lyricsTitle: "歌詞",
    lyricsLede: "歌詞は小さなカプセルの中ではなく、Insula の隣で読む形になっています。 半透明のパネルで、専用の閉じるボタンがあり、画面上の好きな場所にドラッグできます。開いている間も音楽は再生され続けます。",
    lyricsGrab: "ここをつかむ",
    lyricsCorner: "角 — サイズ",
    editWhy: "すべてのボタンが全員に必要なわけではありません。使わないものはカプセルに置いておく必要はありません。",
    editBody: "切り欠き近くの右側にある鉛筆アイコンをタップすると編集モードに入ります。もう一度タップするか「完了」をタップすると終了します。",
    editTitle: "編集",
    editLede: "切り欠き近くの右側にある鉛筆アイコンをタップすると編集モードに入ります。もう一度タップするか「完了」をタップすると終了します。 編集モード中に Insula 上のボタンをタップするとトレイへ送られます。トレイのタイルをタップすると元に戻せます。キラキラのアイコンは一時停止・スキップの発光アニメーションのオン/オフ切り替えです。「完了」をタップすると編集モードを終了します。",
    editTrayLab: "トレイ",
    getTitle: "Macでは無料",
    getBody: "macOS 14以降。App Storeではない。ディスクイメージ。ダウンロード後、聞かれたら右クリック → 開く。",
    reqs: "ジャケットと再生は Music か Spotify から。",
    donate: "寄付のリンクができたらここに置く。",
    partner: "提携 — このページにフォームはない。",
    privacy: "プライバシー",
    missing: "ビルドはまだ downloads/Insula.dmg にない。",
    song: "Night Harbor",
    artist: "Local",
    allOn: "すべて Insula 上",
    done: "Done",
    playAnim: "見る",
    playAgain: "もう一度",
  },
};

const LANGS = ["ja", "zh", "en", "es", "pt", "ru"];
const KEY = "island.site.lang";

function applyCopy(lang) {
  const t = COPY[lang] || COPY.ru;
  document.documentElement.lang = lang;
  document.querySelectorAll("[data-i]").forEach((node) => {
    const key = node.getAttribute("data-i");
    if (t[key] != null) node.textContent = t[key];
  });
  document.title = `${t.title} — ${t.kicker}`;
  document.querySelectorAll(".lang-btn").forEach((btn) => {
    btn.setAttribute("aria-pressed", String(btn.dataset.lang === lang));
  });
  const map = document.querySelector("#map");
  if (map?.dataset.spot) showMapSpot(map.dataset.spot, { pause: map.dataset.pauseTour === "1" });
}

function initLang() {
  const saved = localStorage.getItem(KEY);
  const fromNav = (navigator.language || "ru").slice(0, 2);
  const lang = LANGS.includes(saved) ? saved : LANGS.includes(fromNav) ? fromNav : "ru";
  applyCopy(lang);
  document.querySelectorAll(".lang-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      localStorage.setItem(KEY, btn.dataset.lang);
      applyCopy(btn.dataset.lang);
    });
  });
}

function tickClock() {
  const el = document.querySelector(".clock");
  if (!el) return;
  const now = new Date();
  const wk = new Intl.DateTimeFormat(document.documentElement.lang || "ru", {
    weekday: "short",
  }).format(now);
  const hm = new Intl.DateTimeFormat(document.documentElement.lang || "ru", {
    hour: "numeric",
    minute: "2-digit",
  }).format(now);
  el.textContent = `${wk} ${hm}`;
}

function liveIsland() {
  const wrap = document.querySelector(".island-wrap");
  const island = document.querySelector(".live-island");
  if (!wrap || !island) return;

  const tracks = [
    { title: "Night Harbor", artist: "Local", hue: 18, dur: 222 },
    { title: "Glass Road", artist: "North", hue: 210, dur: 187 },
    { title: "Quiet Room", artist: "Harbor", hue: 330, dur: 241 },
  ];

  const state = {
    i: 0,
    t: 84,
    playing: true,
    route: "headphones",
    muted: false,
    h: 12,
    m: 0,
    s: 0,
    remain: 12 * 3600,
    running: false,
  };

  let closeTimer = 0;
  let openTimer = 0;
  let morphTimer = 0;
  let morphing = false;
  const MORPH_MS = 520;
  const slot = document.querySelector(".island-slot");
  const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s) % 60).padStart(2, "0")}`;
  const pad = (n) => String(n).padStart(2, "0");

  const syncSlot = () => {
    if (!slot) return;
    // Slot height is reserved; only grow for tall panels
    const tall = island.classList.contains("is-open") && island.classList.contains("is-tall");
    slot.classList.toggle("is-taller", tall);
  };

  const beginMorph = () => {
    morphing = true;
    island.classList.add("is-morphing");
    clearTimeout(morphTimer);
    morphTimer = setTimeout(() => {
      morphing = false;
      island.classList.remove("is-morphing");
    }, MORPH_MS);
  };

  island.addEventListener("transitionend", (e) => {
    if (e.target !== island) return;
    if (e.propertyName !== "transform" && e.propertyName !== "height") return;
    morphing = false;
    island.classList.remove("is-morphing");
  });

  const open = () => {
    clearTimeout(closeTimer);
    if (island.classList.contains("is-open")) return;
    beginMorph();
    // Slot + island class in the same frame to avoid two-step layout
    island.classList.add("is-open");
    syncSlot();
  };
  const close = () => {
    if (!island.classList.contains("is-open")) return;
    beginMorph();
    island.classList.remove("is-open");
    syncSlot();
  };

  island.addEventListener("pointerenter", () => {
    clearTimeout(closeTimer);
    clearTimeout(openTimer);
    openTimer = setTimeout(open, 90);
  });
  island.addEventListener("pointerdown", () => {
    clearTimeout(openTimer);
    open();
  });
  wrap.addEventListener("pointerleave", () => {
    clearTimeout(openTimer);
    closeTimer = setTimeout(close, 160);
  });

  function wheelHtml(value, max) {
    const prev = (value + max - 1) % max;
    const next = (value + 1) % max;
    const show = (n) => (max > 24 ? pad(n) : n);
    return `<span>${show(prev)}</span><span class="on">${show(value)}</span><span>${show(next)}</span>`;
  }

  function paintWheels() {
    island.querySelector('[data-unit="h"]').innerHTML = wheelHtml(state.h, 24);
    island.querySelector('[data-unit="m"]').innerHTML = wheelHtml(state.m, 60);
    island.querySelector('[data-unit="s"]').innerHTML = wheelHtml(state.s, 60);
  }

  function paintTrack() {
    const tr = tracks[state.i];
    island.querySelectorAll(".js-title").forEach((el) => {
      el.textContent = tr.title;
    });
    island.querySelectorAll(".js-artist").forEach((el) => {
      el.textContent = tr.artist;
    });
    island.querySelectorAll(".js-art").forEach((el) => {
      el.style.setProperty("--art", String(tr.hue));
    });
    island.querySelectorAll(".js-dur").forEach((el) => {
      el.textContent = fmt(tr.dur);
    });
    island.querySelectorAll(".js-playlist button").forEach((btn) => {
      btn.classList.toggle("is-on", Number(btn.dataset.track) === state.i);
    });
  }

  function paintTime() {
    const tr = tracks[state.i];
    island.querySelectorAll(".js-now").forEach((el) => {
      el.textContent = fmt(state.t);
    });
    const circ = 2 * Math.PI * 4.5;
    island.querySelectorAll(".js-ring").forEach((el) => {
      el.style.strokeDashoffset = String(circ * (1 - state.t / tr.dur));
    });
    island.querySelectorAll(".js-bar i").forEach((el) => {
      el.style.width = `${(state.t / tr.dur) * 100}%`;
    });
  }

  function paintTimer() {
    const label = state.running
      ? fmt(state.remain)
      : `${state.h}:${pad(state.m)}`;
    island.querySelectorAll(".js-timer").forEach((el) => {
      el.textContent = label;
    });
  }

  function paintFlags() {
    island.classList.toggle("is-paused", !state.playing);
    island.classList.toggle("is-tall", island.classList.contains("show-clip") || island.classList.contains("show-lyrics") || island.classList.contains("show-list"));
    syncSlot();
    island.querySelector("[data-act=mic]").classList.toggle("mic-off", state.muted);
    island.querySelectorAll(".out").forEach((btn) => {
      btn.classList.toggle("is-on", btn.dataset.route === state.route);
    });
  }

  function togglePanel(name) {
    const on = island.classList.contains(name);
    island.classList.remove("show-clip", "show-lyrics", "show-list");
    if (!on) island.classList.add(name);
    paintFlags();
  }

  island.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-act], [data-route], [data-unit], [data-track], .js-bar, .js-clip button");
    if (!btn) return;
    e.preventDefault();
    e.stopPropagation();

    if (btn.dataset.act === "play") state.playing = !state.playing;
    if (btn.dataset.act === "prev") state.i = (state.i + tracks.length - 1) % tracks.length;
    if (btn.dataset.act === "next") state.i = (state.i + 1) % tracks.length;
    if (btn.dataset.act === "mic") state.muted = !state.muted;
    if (btn.dataset.act === "clip") togglePanel("show-clip");
    // Subtitles are shown in the #lyrics demo below — not inline on the live island
    if (btn.dataset.act === "lyrics") return;
    if (btn.dataset.act === "playlist") togglePanel("show-list");
    if (btn.dataset.act === "guide" || btn.dataset.act === "edit") {
      const map = document.querySelector("#map");
      if (map) map.scrollIntoView({ behavior: "smooth", block: "start" });
    }
    if (btn.dataset.route) state.route = btn.dataset.route;
    if (btn.dataset.unit === "h") state.h = (state.h + 1) % 24;
    if (btn.dataset.unit === "m") state.m = (state.m + 1) % 60;
    if (btn.dataset.unit === "s") {
      state.s = (state.s + 1) % 60;
      state.remain = state.h * 3600 + state.m * 60 + state.s;
      state.running = state.remain > 0;
    }
    if (btn.dataset.track != null) {
      state.i = Number(btn.dataset.track);
      state.t = 0;
      state.playing = true;
    }
    if (btn.classList.contains("js-bar")) {
      const box = btn.getBoundingClientRect();
      state.t = Math.max(0, Math.min(tracks[state.i].dur, ((e.clientX - box.left) / box.width) * tracks[state.i].dur));
    }
    if (btn.closest(".js-clip")) {
      btn.classList.add("is-on");
      setTimeout(() => btn.classList.remove("is-on"), 500);
    }
    if (btn.dataset.act === "prev" || btn.dataset.act === "next") {
      state.t = 0;
      paintTrack();
    }
    paintFlags();
    paintWheels();
    paintTime();
    paintTimer();
  });

  paintTrack();
  paintWheels();
  paintTime();
  paintTimer();
  paintFlags();

  setInterval(() => {
    if (morphing) return;
    if (state.playing) {
      state.t += 0.25;
      if (state.t > tracks[state.i].dur) {
        state.i = (state.i + 1) % tracks.length;
        state.t = 0;
        paintTrack();
      }
      paintTime();
    }
    if (state.running && state.remain > 0) {
      state.remain -= 0.25;
      if (state.remain <= 0) {
        state.remain = 0;
        state.running = false;
      }
      paintTimer();
    }
  }, 250);
}

const MAP_SPOTS = ["timer", "edit", "guide", "mic", "clipboard", "media", "lyrics", "playlist", "progress", "anim"];

function mapCopy() {
  const lang = localStorage.getItem(KEY) || document.documentElement.lang || "ru";
  return COPY[lang] || COPY.ru;
}

function showMapSpot(spot, { pause = true } = {}) {
  const root = document.querySelector("#map");
  if (!root || !MAP_SPOTS.includes(spot)) return;
  const t = mapCopy();
  const title = root.querySelector(".map-story-title");
  const body = root.querySelector(".map-story-body");
  if (title) title.textContent = t[spot] || spot;
  if (body) body.textContent = t[`${spot}How`] || "";

  root.querySelectorAll(".map-hit").forEach((el) => {
    el.classList.toggle("is-hot", el.dataset.spot === spot);
  });
  root.querySelectorAll(".map-tab").forEach((el) => {
    const on = el.dataset.spot === spot;
    el.setAttribute("aria-selected", on ? "true" : "false");
    el.classList.toggle("is-on", on);
  });
  root.dataset.spot = spot;
  const island = root.querySelector(".chart-island");
  if (island) island.classList.add("is-picking");
  if (pause) root.dataset.pauseTour = "1";
}

function bindMapTour() {
  const root = document.querySelector("#map");
  if (!root) return;

  const activate = (spot, pause = true) => {
    showMapSpot(spot, { pause });
  };

  root.addEventListener("click", (e) => {
    const hit = e.target.closest("[data-spot]");
    if (!hit || !root.contains(hit)) return;
    activate(hit.dataset.spot, true);
  });

  root.addEventListener("keydown", (e) => {
    if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
    const cur = root.dataset.spot || "timer";
    const i = MAP_SPOTS.indexOf(cur);
    if (i < 0) return;
    e.preventDefault();
    const next = e.key === "ArrowRight"
      ? MAP_SPOTS[(i + 1) % MAP_SPOTS.length]
      : MAP_SPOTS[(i - 1 + MAP_SPOTS.length) % MAP_SPOTS.length];
    activate(next, true);
  });

  // Soft auto-tour while the section is on screen; stops after user picks
  let idx = 0;
  let timer = 0;
  const tick = () => {
    if (root.dataset.pauseTour === "1") return;
    idx = (idx + 1) % MAP_SPOTS.length;
    activate(MAP_SPOTS[idx], false);
  };

  const io = new IntersectionObserver(
    ([entry]) => {
      window.clearInterval(timer);
      if (!entry.isIntersecting) return;
      if (root.dataset.pauseTour === "1") return;
      timer = window.setInterval(tick, 4200);
    },
    { threshold: 0.35 }
  );
  io.observe(root);

  activate("timer", false);
}


async function downloadGuard() {
  const links = document.querySelectorAll('a.download[href$="Insula.dmg"]');
  const note = document.querySelector(".note");
  let ok = false;
  try {
    const res = await fetch("downloads/Insula.dmg", { method: "HEAD" });
    ok = res.ok;
  } catch {
    ok = false;
  }
  links.forEach((a) => {
    a.addEventListener("click", (e) => {
      if (ok) return;
      e.preventDefault();
      if (note) {
        const t = COPY[localStorage.getItem(KEY) || document.documentElement.lang] || COPY.ru;
        note.textContent = t.missing;
      }
    });
  });
}

function goDark() {
  document.documentElement.classList.add("is-dark");
  document.documentElement.style.colorScheme = "dark";
  const theme = document.querySelector('meta[name="theme-color"]');
  if (theme) theme.setAttribute("content", "#07080b");
  const scheme = document.querySelector('meta[name="color-scheme"]');
  if (scheme) scheme.setAttribute("content", "dark");
}

function initRise() {
  document.querySelectorAll(".rise, .rise-stay").forEach((node) => {
    node.classList.add("is-in");
  });
}

function playGate() {
  initRise();
  const body = document.body;
  const gate = document.getElementById("gate");
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const timers = [];
  const later = (fn, ms) => {
    const id = setTimeout(fn, ms);
    timers.push(id);
    return id;
  };

  const finish = () => {
    if (body.classList.contains("is-ready")) return;
    timers.forEach(clearTimeout);
    goDark();
    body.classList.add("is-night", "is-ready", "is-shatter");
    body.classList.remove("booting", "is-crack");
    if (gate) {
      gate.classList.add("is-done");
      later(() => gate.remove(), 520);
    }
    initRise();
    
  };

  if (reduce || !gate) {
    finish();
    return;
  }

  gate.addEventListener("click", finish);
  window.addEventListener(
    "keydown",
    (event) => {
      if (event.key === "Escape" || event.key === "Enter") finish();
    },
    { once: true }
  );

  // Site already under the matte pane
  goDark();
  body.classList.add("is-night");
  initRise();

  // 1) Frosted glass settles in — site barely readable behind it
  later(() => {
    if (body.classList.contains("is-ready")) return;
    gate.classList.add("is-frost");
  }, 80);

  // 2) Crack walks the island edge
  later(() => {
    if (body.classList.contains("is-ready")) return;
    gate.classList.add("is-crack");
    body.classList.add("is-crack");
  }, 1200);

  // 3) Hold on the cracked pane, then the rest shatters at once
  later(() => {
    if (body.classList.contains("is-ready")) return;
    gate.classList.add("is-shatter");
    body.classList.add("is-shatter");
  }, 3100);

  // 4) Clear
  later(() => {
    if (body.classList.contains("is-ready")) return;
    gate.classList.add("is-done");
    later(() => {
      if (body.classList.contains("is-ready")) return;
      body.classList.add("is-ready");
      body.classList.remove("booting", "is-crack");
      gate.remove();
      
    }, 700);
  }, 4600);
}

function tipOn(el, origin, ox, oy) {
  const o = origin.getBoundingClientRect();
  const r = el.getBoundingClientRect();
  const sx = origin.offsetWidth ? o.width / origin.offsetWidth : 1;
  const sy = origin.offsetHeight ? o.height / origin.offsetHeight : 1;
  return [
    (r.left - o.left + r.width * ox) / (sx || 1),
    (r.top - o.top + r.height * oy) / (sy || 1),
  ];
}

function measureTraySlot(stage, origin) {
  const slot = stage.querySelector(".edit-mic-off");
  const spark = stage.querySelector(".spark");
  if (slot) {
    const width = slot.style.width;
    const minWidth = slot.style.minWidth;
    const opacity = slot.style.opacity;
    const margin = slot.style.margin;
    slot.style.width = "26px";
    slot.style.minWidth = "26px";
    slot.style.opacity = "0";
    slot.style.margin = "0";
    const point = tipOn(slot, origin, 0, 0);
    slot.style.width = width;
    slot.style.minWidth = minWidth;
    slot.style.opacity = opacity;
    slot.style.margin = margin;
    return point;
  }
  if (spark) return tipOn(spark, origin, 1, 0);
  return [64, 158];
}

function setCursorPoint(node, name, x, y) {
  node.style.setProperty(`--${name}-x`, `${Math.round(x)}px`);
  node.style.setProperty(`--${name}-y`, `${Math.round(y)}px`);
}

const MOTION = {
  ease: "cubic-bezier(0.16, 1, 0.3, 1)",
  spring: "cubic-bezier(0.32, 0.72, 0, 1)",
};

function playLyricsDemo(stage) {
  const card = stage.querySelector(".lyrics-card");
  const cursor = stage.querySelector(".lyrics-cursor");
  const stack = stage.querySelector(".lyrics-stack");
  const lines = [...stage.querySelectorAll(".lyrics-line")];
  if (!card || !cursor || !stack) return;

  const travel = MOTION.spring;
  const restW = 320;
  const restH = 120;
  const bigW = 480;
  const bigH = 220;
  const smallW = 248;
  const smallH = 96;
  const mx = 48;
  const my = 36;
  const lyricScale = (w, h) => {
    const value = Math.sqrt((w / restW) * (h / restH));
    return Math.min(Math.max(value, 0.72), 2.4);
  };
  const setLine = (index) => {
    lines.forEach((el, n) => {
      el.classList.toggle("is-on", n === index);
      el.classList.toggle("is-prev", n === index - 1);
      el.classList.toggle("is-next", n === index + 1);
    });
    stack.style.setProperty("--i", String(index));
  };
  const stick = () => {
    cursor.getAnimations().forEach((anim) => anim.cancel());
    cursor.style.left = "calc(100% - 17px)";
    cursor.style.top = "calc(100% - 17px)";
    cursor.style.transform = "none";
    cursor.style.opacity = "1";
    card.classList.add("is-sizing");
  };
  const unstick = () => {
    card.classList.remove("is-sizing");
    cursor.style.left = "0";
    cursor.style.top = "0";
    cursor.style.transform = "";
    cursor.style.opacity = "";
  };

  (stage._lyricTimers || []).forEach(clearTimeout);
  stage._lyricTimers = [];
  const later = (fn, ms) => {
    const id = setTimeout(fn, ms);
    stage._lyricTimers.push(id);
  };

  unstick();
  setLine(2);
  const [gx, gy] = tipOn(card, card, 0.5, 0.55);
  const ax = gx + 36;
  const ay = gy + 48;
  const handle = (w, h) => [w - 17, h - 17];
  const [s0x, s0y] = handle(restW, restH);

  const cur = (x, y, scale, opacity, easing) => ({
    transform: `translate(${x}px, ${y}px) scale(${scale})`,
    opacity: String(opacity),
    easing,
  });
  const panel = (x, y, w, h, easing) => ({
    transform: `translate(${x}px, ${y}px)`,
    width: `${w}px`,
    height: `${h}px`,
    fontSize: `${(12 * lyricScale(w, h)).toFixed(2)}px`,
    easing,
  });

  cursor.getAnimations().forEach((anim) => anim.cancel());
  card.getAnimations().forEach((anim) => anim.cancel());

  cursor.animate(
    [
      cur(ax, ay, 1, 0, travel),
      { ...cur(gx, gy, 1, 1, "ease-out"), offset: 0.08 },
      { ...cur(gx, gy, 0.94, 1, MOTION.ease), offset: 0.11 },
      { ...cur(gx, gy, 1, 1, "linear"), offset: 0.14 },
      { ...cur(gx, gy, 1, 1, travel), offset: 0.46 },
      { ...cur(s0x, s0y, 1, 1, "ease-out"), offset: 0.56 },
      { ...cur(s0x, s0y, 0.94, 1, MOTION.ease), offset: 0.59 },
      { ...cur(s0x, s0y, 1, 1, travel), offset: 0.62 },
    ],
    { duration: 9920, easing: "linear", fill: "forwards" }
  );

  later(stick, 9920);

  later(() => {
    unstick();
    const [hx, hy] = handle(smallW, smallH);
    cursor.animate(
      [
        cur(hx, hy, 1, 1, "ease"),
        { ...cur(hx + 36, hy + 48, 1, 0, "ease"), offset: 1 },
      ],
      { duration: 1600, easing: "linear", fill: "forwards" }
    );
  }, 14400);

  card.animate(
    [
      panel(0, 0, restW, restH, "linear"),
      { ...panel(0, 0, restW, restH, travel), offset: 0.16 },
      { ...panel(mx, my, restW, restH, "linear"), offset: 0.46 },
      { ...panel(mx, my, restW, restH, travel), offset: 0.62 },
      { ...panel(mx, my, bigW, bigH, travel), offset: 0.74 },
      { ...panel(mx, my, bigW, bigH, "linear"), offset: 0.82 },
      { ...panel(mx, my, smallW, smallH, "linear"), offset: 0.9 },
      { ...panel(0, 0, restW, restH, "ease"), offset: 1 },
    ],
    { duration: 16000, easing: "linear", fill: "forwards" }
  );

  [2, 3, 4, 5, 2].forEach((index, step) => {
    later(() => setLine(index), 1800 + step * 2400);
  });
}

function playEditCursor(stage) {
  const origin = stage.querySelector(".edit-stack");
  const desk = stage.querySelector(".edit-desk");
  const cursor = stage.querySelector(".edit-cursor");
  const pencil = stage.querySelector(".edit-pencil");
  const mic = stage.querySelector(".edit-mic-on");
  const spark = stage.querySelector(".spark");
  const fly = stage.querySelector(".edit-fly");
  if (!origin || !cursor || !pencil) return;

  const travel = MOTION.spring;
  const [px, py] = tipOn(pencil, origin, 0.45, 0.4);
  const minus = mic?.querySelector(".edit-minus");
  const [mx, my] = minus
    ? tipOn(minus, origin, 0.5, 0.5)
    : mic
      ? tipOn(mic, origin, 0.92, 0.08)
      : [px + 40, py];
  let tx;
  let ty;
  if (spark) {
    const [sx, sy] = tipOn(spark, origin, 1, 0.5);
    tx = sx + 14;
    ty = sy;
  } else {
    tx = 64;
    ty = 158;
  }
  const ax = px + 28;
  const ay = py + 36;
  const at = (x, y, scale, opacity, easing) => ({
    transform: `translate(${Math.round(x)}px, ${Math.round(y)}px) scale(${scale})`,
    opacity: String(opacity),
    easing,
  });

  cursor.getAnimations().forEach((anim) => anim.cancel());
  cursor.animate(
    [
      at(ax, ay, 1, 0, travel),
      { ...at(px, py, 1, 1, "ease-out"), offset: 0.08 },
      { ...at(px, py, 0.98, 1, MOTION.ease), offset: 0.11 },
      { ...at(px, py, 1, 1, travel), offset: 0.15 },
      { ...at(mx, my, 1, 1, "ease-out"), offset: 0.24 },
      { ...at(mx, my, 0.98, 1, MOTION.ease), offset: 0.28 },
      { ...at(mx, my, 1, 1, travel), offset: 0.32 },
      { ...at(tx, ty, 1, 1, "linear"), offset: 0.44 },
      { ...at(tx, ty, 1, 1, "ease-out"), offset: 0.52 },
      { ...at(tx, ty, 0.98, 1, MOTION.ease), offset: 0.56 },
      { ...at(tx, ty, 1, 1, travel), offset: 0.6 },
      { ...at(px, py, 1, 1, travel), offset: 0.74 },
      { ...at(px, py, 0.98, 1, MOTION.ease), offset: 0.78 },
      { ...at(px, py, 1, 1, "ease"), offset: 0.82 },
      { ...at(ax, ay, 1, 0, "ease"), offset: 1 },
    ],
    { duration: 8000, easing: "linear", fill: "forwards" }
  );

  if (fly && mic && desk) {
    const [x0, y0] = tipOn(mic, desk, 0, 0);
    const [x1, y1] = measureTraySlot(stage, desk);
    const [colL] = tipOn(origin, desk, 0, 0);
    const [colR] = tipOn(origin, desk, 1, 0);
    const clampX = (x) => Math.min(Math.max(x, colL), colR - 26);
    const aX = Math.round(clampX(x0));
    const aY = Math.round(y0);
    const bX = Math.round(clampX(x1));
    const bY = Math.round(y1);
    const pose = (x, y, scale, opacity, easing) => ({
      transform: `translate(${x}px, ${y}px) scale(${scale})`,
      opacity: String(opacity),
      easing,
    });
    fly.getAnimations().forEach((anim) => anim.cancel());
    fly.animate(
      [
        pose(aX, aY, 1, 0, "linear"),
        { ...pose(aX, aY, 1, 0, "ease-out"), offset: 0.22 },
        { ...pose(aX, aY, 1, 1, travel), offset: 0.26 },
        { ...pose(bX, bY, 1, 1, "ease-in"), offset: 0.4 },
        { ...pose(bX, bY, 1, 0, "linear"), offset: 0.44 },
        { ...pose(bX, bY, 1, 0, "linear"), offset: 0.54 },
        { ...pose(bX, bY, 1, 1, travel), offset: 0.58 },
        { ...pose(aX, aY, 1, 1, "ease-in"), offset: 0.7 },
        { ...pose(aX, aY, 1, 0, "linear"), offset: 0.74 },
        { ...pose(aX, aY, 1, 0, "linear"), offset: 1 },
      ],
      { duration: 8000, easing: "linear", fill: "forwards" }
    );
  }
}

function setPlayLabel(btn, key) {
  const span = btn.querySelector("[data-i]");
  if (!span) return;
  span.setAttribute("data-i", key);
  const lang = document.documentElement.lang || "ru";
  const t = COPY[lang] || COPY.ru;
  if (t[key]) span.textContent = t[key];
}

function runPlayScene(btn) {
  const scene = btn.dataset.play;
  const stage = document.querySelector(`[data-scene="${scene}"]`);
  if (!stage || btn.disabled) return;
  const times = { lyrics: 16000, edit: 8500, move: 14500 };
  btn.disabled = true;
  stage.classList.remove("is-playing");
  void stage.offsetWidth;
  stage.classList.add("is-playing");
  if (scene === "lyrics") {
    window.requestAnimationFrame(() => playLyricsDemo(stage));
  }
  if (scene === "edit") {
    window.requestAnimationFrame(() => playEditCursor(stage));
  }
  window.setTimeout(() => {
    btn.disabled = false;
    setPlayLabel(btn, "playAgain");
  }, times[scene] || 16000);
}

function initPlayAnims() {
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  document.querySelectorAll("[data-play]").forEach((btn) => {
    const stage = document.querySelector(`[data-scene="${btn.dataset.play}"]`);
    btn.addEventListener("click", () => runPlayScene(btn));
    if (reduce || !stage) return;
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting || stage.dataset.autoplayed) return;
          stage.dataset.autoplayed = "1";
          runPlayScene(btn);
        });
      },
      { threshold: 0.42, rootMargin: "0px 0px -8% 0px" }
    );
    io.observe(stage);
  });
}

initLang();
tickClock();
setInterval(tickClock, 1000);
liveIsland();
downloadGuard();
initPlayAnims();
playGate();
bindMapTour();

