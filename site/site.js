const LANGS_ON_SITE = "日本語, 中文, English, Español, Português, Русский";

const COPY = {
  ru: {
    navMap: "Карта",
    navGet: "Скачать",
    kicker: "для Mac",
    title: "Island",
    lede: "У камеры Mac. Музыка, таймер и буфер — без отдельного окна и без кружка в Dock.",
    download: "Скачать для Mac",
    win: "Windows — в планах",
    hover: "наведите на остров",
    lidNotch: "с челкой",
    lidNone: "без челки",
    mapTitle: "Что на острове",
    mapLede: "Развёрнутый остров. Стрелка к тому, что уже есть — без ролика.",
    timer: "Таймер",
    timerHow: "Левое ухо: часы, минуты, секунды. В конце — звук, уведомление, музыка на паузе.",
    edit: "Редакт",
    editHow: "Карандаш у выреза. Лишние кнопки снимаются в лоток, не пропадают.",
    guide: "Гайд",
    guideHow: `Тур поверх экрана: зачем, потом как. ${LANGS_ON_SITE}.`,
    clipboard: "Буфер",
    clipboardHow: "Последние пять текстов. Тап по строке — копирует снова.",
    media: "Медиа",
    mediaHow: "Обложка, название, назад / пауза / дальше. Куда звук: колонки, наушники, Mac.",
    playlist: "Плейлист",
    playlistHow: "Кнопка списка только если Music отдал текущую очередь.",
    progress: "Прогресс",
    progressHow: "Полоса внизу. Её можно перетащить, чтобы перемотать.",
    anim: "Анимации",
    animHow: "Искра в лотке. Пауза и перемотка подсвечиваются, если включить там.",
    hoverWhy: "Наведение, не клик",
    hoverBody: "Раскрывается только если курсор на самом острове. Проскочил мимо — большой не открывается. Задержись около 0.1 с. Медленно — сначала щель в стекле, большой у камеры.",
    moveWhy: "Перенос",
    moveBody: "Три клика за полторы секунды — остров едет за курсором и липнет к краю. Кнопка у камеры возвращает домой.",
    moveTitle: "Перенос",
    moveLede: "Не наведение. Три клика за полторы секунды — остров едет за курсором и липнет к краю. Сбоку — карточка у стены. Снизу — пилюля. У камеры кнопка: тап — домой.",
    moveHouse: "домой",
    moveSide: "сбоку",
    moveBottom: "снизу",
    moveClicks: "три клика",
    micWhy: "Микрофон на весь Mac",
    micBody: "Один тап глушит вход для Zoom, Discord и всего остального. Белый — вас слышно. Красный на белом — нет.",
    lyricsWhy: "Текст рядом",
    lyricsBody: "Песня на остров не влезает. Пузырёк открывает стеклянную панель, её можно двигать и тянуть за угол.",
    lyricsTitle: "Субтитры",
    lyricsLede: "Текст на остров не влезает. Пузырёк открывает стеклянную панель рядом. Тащить можно за само стекло — не за крестик и не за белый кружок в углу.",
    lyricsGrab: "тянуть здесь",
    lyricsCorner: "угол — размер",
    editWhy: "Своя раскладка",
    editBody: "Не всем нужны все кнопки. Карандаш открывает лоток: поставил, снял, готово.",
    editTitle: "Редакт",
    editLede: "Карандаш в правом ухе, у выреза. Кнопки, которыми не пользуешься, снимаются в лоток под островом — они не пропадают. Тап по фишке в лотке возвращает её на остров. Done или снова карандаш — выход. Медиа и вырез снять нельзя.",
    editTrayLab: "лоток",
    getTitle: "Бесплатно на Mac",
    getBody: "macOS 14 и новее. Не из App Store — обычный диск. После скачивания: правый клик → Открыть, если система спросит.",
    reqs: "Обложка и кнопки трека — из Music или Spotify.",
    donate: "Донат появится здесь, когда будет ссылка.",
    partner: "Партнёрство — без формы на этой странице.",
    privacy: "Политика",
    missing: "Файл сборки ещё не лежит в downloads/Island.dmg.",
    song: "Night Harbor",
    artist: "Local",
    allOn: "All on the island",
    done: "Done",
    playAnim: "Смотреть",
    playAgain: "Ещё раз",
  },
  en: {
    navMap: "Map",
    navGet: "Download",
    kicker: "for Mac",
    title: "Island",
    lede: "The island sits at the camera. Music, a timer, and the clipboard — no extra window, no Dock icon.",
    download: "Download for Mac",
    win: "Windows — planned",
    hover: "hover the island",
    lidNotch: "with notch",
    lidNone: "no notch",
    mapTitle: "What’s on the island",
    mapLede: "The island, expanded. Arrows to what already exists — no video.",
    timer: "Timer",
    timerHow: "Left ear: hours, minutes, seconds. At the end: sound, a notification, music pauses.",
    edit: "Edit",
    editHow: "The pencil by the notch. Extra buttons go to the tray; they aren’t lost.",
    guide: "Guide",
    guideHow: `A tour on the screen: why, then how. ${LANGS_ON_SITE}.`,
    clipboard: "Clipboard",
    clipboardHow: "The last five texts. Tap a row to copy it again.",
    media: "Media",
    mediaHow: "Artwork, title, back / pause / next. Sound goes to speakers, headphones, or Mac.",
    playlist: "Playlist",
    playlistHow: "The list button appears only if Music gives the current queue.",
    progress: "Progress",
    progressHow: "The bar at the bottom. Drag it to scrub.",
    anim: "Animations",
    animHow: "The sparkle in the tray. Pause and skip light up if you turn them on there.",
    hoverWhy: "Hover, not a click",
    hoverBody: "It opens only when the cursor is on the island. A quick pass-through does not open it. Stay about 0.1 s. Approach slowly — a gap in the glass first, large near the camera.",
    moveWhy: "Move it",
    moveBody: "Three clicks in a second and a half — the island follows the cursor and sticks to an edge. The button by the camera sends it home.",
    moveTitle: "Move",
    moveLede: "Not a hover. Three clicks in a second and a half — the island follows the cursor and sticks to an edge. On the side it becomes a card. At the bottom, a pill. A home button stays by the camera: tap it to go back.",
    moveHouse: "home",
    moveSide: "side",
    moveBottom: "bottom",
    moveClicks: "three clicks",
    micWhy: "Mic for the whole Mac",
    micBody: "One tap mutes input for Zoom, Discord, everything. White — they hear you. Red on white — they don’t.",
    lyricsWhy: "Lyrics beside",
    lyricsBody: "The song doesn’t fit on the island. The bubble opens a glass panel you can move and resize.",
    lyricsTitle: "Lyrics",
    lyricsLede: "The song doesn’t fit on the island. The bubble opens a glass panel beside it. Drag the glass itself — not the close button, not the white dot in the corner.",
    lyricsGrab: "drag here",
    lyricsCorner: "corner — size",
    editWhy: "Your layout",
    editBody: "Not everyone needs every button. The pencil opens the tray: put it on, take it off, Done.",
    editTitle: "Edit",
    editLede: "The pencil sits in the right ear, by the notch. Buttons you don’t use go to the tray under the island — they aren’t lost. Tap a chip in the tray to put it back. Done, or the pencil again, to leave. Media and the notch stay.",
    editTrayLab: "tray",
    getTitle: "Free on Mac",
    getBody: "macOS 14 and later. Not the App Store — a disk image. After download: right-click → Open if the system asks.",
    reqs: "Artwork and track buttons come from Music or Spotify.",
    donate: "A donate link will sit here when there is one.",
    partner: "Partnership — no form on this page.",
    privacy: "Privacy",
    missing: "The build is not in downloads/Island.dmg yet.",
    song: "Night Harbor",
    artist: "Local",
    allOn: "All on the island",
    done: "Done",
    playAnim: "Watch",
    playAgain: "Watch again",
  },
  es: {
    navMap: "Mapa",
    navGet: "Descargar",
    kicker: "para Mac",
    title: "Isla",
    lede: "La isla está en la cámara. Música, temporizador y portapapeles — sin otra ventana ni icono en el Dock.",
    download: "Descargar para Mac",
    win: "Windows — en planes",
    hover: "pasa el cursor por la isla",
    lidNotch: "con recorte",
    lidNone: "sin recorte",
    mapTitle: "Qué hay en la isla",
    mapLede: "La isla abierta. Flechas a lo que ya existe — sin vídeo.",
    timer: "Temporizador",
    timerHow: "Oreja izquierda: horas, minutos, segundos. Al terminar: sonido, aviso, la música se pausa.",
    edit: "Editar",
    editHow: "El lápiz junto al recorte. Los botones de más van a la bandeja; no se pierden.",
    guide: "Guía",
    guideHow: `Un recorrido en pantalla: para qué, luego cómo. ${LANGS_ON_SITE}.`,
    clipboard: "Portapapeles",
    clipboardHow: "Los últimos cinco textos. Un toque en una línea la vuelve a copiar.",
    media: "Medios",
    mediaHow: "Carátula, título, atrás / pausa / adelante. El sonido: altavoz, auriculares o Mac.",
    playlist: "Lista",
    playlistHow: "El botón de lista sale solo si Music entrega la cola actual.",
    progress: "Progreso",
    progressHow: "La barra abajo. Arrástrala para saltar.",
    anim: "Animaciones",
    animHow: "La chispa en la bandeja. Pausa y salto se marcan si las enciendes ahí.",
    hoverWhy: "Pasar el cursor, no un clic",
    hoverBody: "Se abre solo si el cursor está en la isla. Si solo pasas de largo, no se abre. Quédate unos 0,1 s. Despacio — primero una hendidura en el cristal, grande junto a la cámara.",
    moveWhy: "Moverla",
    moveBody: "Tres clics en un segundo y medio — la isla sigue el cursor y se pega al borde. El botón junto a la cámara la devuelve.",
    moveTitle: "Mover",
    moveLede: "No es pasar el cursor. Tres clics en un segundo y medio — la isla sigue el cursor y se pega al borde. Al lado, una tarjeta. Abajo, una pastilla. En la cámara queda un botón: un toque y vuelve.",
    moveHouse: "inicio",
    moveSide: "al lado",
    moveBottom: "abajo",
    moveClicks: "tres clics",
    micWhy: "Micrófono de todo el Mac",
    micBody: "Un toque silencia la entrada para Zoom, Discord, todo. Blanco: te oyen. Rojo sobre blanco: no.",
    lyricsWhy: "Letra al lado",
    lyricsBody: "La canción no cabe en la isla. El bocadillo abre un panel de cristal que se mueve y se estira.",
    lyricsTitle: "Subtítulos",
    lyricsLede: "La letra no cabe en la isla. El bocadillo abre un panel de cristal al lado. Arrástralo por el cristal — no por la cruz ni por el punto blanco de la esquina.",
    lyricsGrab: "arrastrar aquí",
    lyricsCorner: "esquina — tamaño",
    editWhy: "Tu disposición",
    editBody: "No todos necesitan todos los botones. El lápiz abre la bandeja: pon, quita, Listo.",
    editTitle: "Editar",
    editLede: "El lápiz está en la oreja derecha, junto al recorte. Los botones que no usas van a la bandeja bajo la isla; no se pierden. Un toque en la bandeja los devuelve. Listo, o el lápiz otra vez, para salir. Los medios y el recorte se quedan.",
    editTrayLab: "bandeja",
    getTitle: "Gratis en Mac",
    getBody: "macOS 14 o posterior. No es el App Store: una imagen de disco. Tras bajar: clic derecho → Abrir si el sistema pregunta.",
    reqs: "La carátula y los botones del tema salen de Music o Spotify.",
    donate: "El enlace de donar estará aquí cuando exista.",
    partner: "Colaboración — no hay formulario en esta página.",
    privacy: "Privacidad",
    missing: "El archivo aún no está en downloads/Island.dmg.",
    song: "Night Harbor",
    artist: "Local",
    allOn: "All on the island",
    done: "Done",
    playAnim: "Ver",
    playAgain: "Ver otra vez",
  },
  pt: {
    navMap: "Mapa",
    navGet: "Baixar",
    kicker: "para Mac",
    title: "Ilha",
    lede: "A ilha fica na câmera. Música, temporizador e área de transferência — sem outra janela e sem ícone no Dock.",
    download: "Baixar para Mac",
    win: "Windows — nos planos",
    hover: "passe o cursor pela ilha",
    lidNotch: "com recorte",
    lidNone: "sem recorte",
    mapTitle: "O que há na ilha",
    mapLede: "A ilha aberta. Setas para o que já existe — sem vídeo.",
    timer: "Temporizador",
    timerHow: "Orelha esquerda: horas, minutos, segundos. Ao terminar: som, aviso, a música pausa.",
    edit: "Editar",
    editHow: "O lápis fica no recorte. Botões a mais vão para a bandeja; não se perdem.",
    guide: "Guia",
    guideHow: `Um percurso na tela: para quê, depois como. ${LANGS_ON_SITE}.`,
    clipboard: "Área de transferência",
    clipboardHow: "Os últimos cinco textos. Toque numa linha para copiar de novo.",
    media: "Mídia",
    mediaHow: "Capa, título, voltar / pausa / avançar. O som: caixas, fones ou Mac.",
    playlist: "Playlist",
    playlistHow: "O botão da lista só aparece se o Music entregar a fila atual.",
    progress: "Progresso",
    progressHow: "A barra embaixo. Arraste para pular.",
    anim: "Animações",
    animHow: "A fagulha na bandeja. Pausa e avanço acendem se você ligar ali.",
    hoverWhy: "Passar o cursor, não um clique",
    hoverBody: "Abre só se o cursor estiver na ilha. Passar depressa não abre. Fique uns 0,1 s. Devagar — primeiro uma fenda no vidro, grande perto da câmera.",
    moveWhy: "Mover",
    moveBody: "Três cliques em um segundo e meio — a ilha segue o cursor e gruda na borda. O botão na câmera manda para casa.",
    moveTitle: "Mover",
    moveLede: "Não é passar o cursor. Três cliques em um segundo e meio — a ilha segue o cursor e gruda na borda. Do lado, um cartão. Embaixo, uma pílula. Na câmera fica um botão: um toque e volta.",
    moveHouse: "início",
    moveSide: "do lado",
    moveBottom: "embaixo",
    moveClicks: "três cliques",
    micWhy: "Microfone do Mac inteiro",
    micBody: "Um toque silencia a entrada para Zoom, Discord, tudo. Branco: ouvem você. Vermelho no branco: não.",
    lyricsWhy: "Letra ao lado",
    lyricsBody: "A letra não cabe na ilha. O balão abre um painel de vidro que se move e estica.",
    lyricsTitle: "Legendas",
    lyricsLede: "A letra não cabe na ilha. O balão abre um painel de vidro ao lado. Arraste pelo vidro — não pelo fechar nem pelo ponto branco no canto.",
    lyricsGrab: "arrastar aqui",
    lyricsCorner: "canto — tamanho",
    editWhy: "Seu layout",
    editBody: "Nem todo mundo precisa de todos os botões. O lápis abre a bandeja: coloca, tira, Pronto.",
    editTitle: "Editar",
    editLede: "O lápis fica na orelha direita, no recorte. Botões que você não usa vão para a bandeja sob a ilha; não se perdem. Um toque na bandeja devolve. Pronto, ou o lápis de novo, para sair. Mídia e recorte ficam.",
    editTrayLab: "bandeja",
    getTitle: "Grátis no Mac",
    getBody: "macOS 14 ou posterior. Não é a App Store: uma imagem de disco. Depois de baixar: clique com o botão direito → Abrir se o sistema perguntar.",
    reqs: "Capa e botões da faixa vêm do Music ou Spotify.",
    donate: "O link de doação fica aqui quando existir.",
    partner: "Parceria — sem formulário nesta página.",
    privacy: "Privacidade",
    missing: "O arquivo ainda não está em downloads/Island.dmg.",
    song: "Night Harbor",
    artist: "Local",
    allOn: "All on the island",
    done: "Done",
    playAnim: "Ver",
    playAgain: "Ver de novo",
  },
  zh: {
    navMap: "地图",
    navGet: "下载",
    kicker: "适用于 Mac",
    title: "岛",
    lede: "岛在摄像头旁。音乐、计时器、剪贴板——没有多余窗口，没有程序坞图标。",
    download: "下载 Mac 版",
    win: "Windows — 计划中",
    hover: "把指针移到岛上",
    lidNotch: "有刘海",
    lidNone: "无刘海",
    mapTitle: "岛上有什么",
    mapLede: "展开后的岛。箭头指向已经有的功能——没有视频。",
    timer: "计时器",
    timerHow: "左耳：时、分、秒。结束时会响、会通知，音乐会暂停。",
    edit: "编辑",
    editHow: "铅笔在刘海旁。多余按钮进托盘，不会丢。",
    guide: "指南",
    guideHow: `屏幕上的导览：先说为什么，再说怎么用。${LANGS_ON_SITE}。`,
    clipboard: "剪贴板",
    clipboardHow: "最近五段文字。点一行会重新复制。",
    media: "媒体",
    mediaHow: "封面、歌名、上一首 / 暂停 / 下一首。声音去音箱、耳机或 Mac。",
    playlist: "播放列表",
    playlistHow: "只有 Music 给出当前队列时才出现列表按钮。",
    progress: "进度",
    progressHow: "底栏。拖动可以跳转。",
    anim: "动画",
    animHow: "托盘里的火花。在那里打开后，暂停和跳转会有提示。",
    hoverWhy: "悬停，不是点击",
    hoverBody: "只有指针在岛上才会展开。快速穿过不会打开。停大约 0.1 秒。慢慢靠近——玻璃上先出现一条缝，靠近摄像头才变大。",
    moveWhy: "挪位置",
    moveBody: "一秒半内连点三次，岛会跟着指针走，并贴到边缘。摄像头旁的按钮把它送回家。",
    moveTitle: "挪位置",
    moveLede: "不是悬停。一秒半内连点三次，岛跟着指针走，贴到边缘。侧面变成卡片，底部是胶囊。摄像头旁是主页按钮：点一下就回家。",
    moveHouse: "主页",
    moveSide: "侧面",
    moveBottom: "底部",
    moveClicks: "点三次",
    micWhy: "整台 Mac 的麦克风",
    micBody: "点一下就关掉输入，Zoom、Discord 全都听不见。白色表示听得见你；白底红标表示听不见。",
    lyricsWhy: "歌词在旁边",
    lyricsBody: "歌词塞不进岛里。气泡打开一块可移动、可拉角的玻璃面板。",
    lyricsTitle: "字幕",
    lyricsLede: "歌词塞不进岛里。气泡在旁边打开一块玻璃面板。拖的是玻璃本身——不是关闭，也不是角落里的白点。",
    lyricsGrab: "从这里拖",
    lyricsCorner: "角落 — 大小",
    editWhy: "自己的布局",
    editBody: "不是每个人都需要全部按钮。铅笔打开托盘：放上、拿下、完成。",
    editTitle: "编辑",
    editLede: "铅笔在右耳、刘海旁。不用的按钮进托盘，不会丢。点托盘里的芯片会回到岛上。Done，或再点铅笔退出。媒体和刘海不能拿掉。",
    editTrayLab: "托盘",
    getTitle: "Mac 上免费",
    getBody: "macOS 14 及更新。不是 App Store，是磁盘映像。下载后若系统询问：右键 → 打开。",
    reqs: "封面和切歌来自 Music 或 Spotify。",
    donate: "有捐赠链接时会放在这里。",
    partner: "合作——本页没有表格。",
    privacy: "隐私",
    missing: "安装包还没有放到 downloads/Island.dmg。",
    song: "Night Harbor",
    artist: "Local",
    allOn: "All on the island",
    done: "Done",
    playAnim: "观看",
    playAgain: "再看一次",
  },
  ja: {
    navMap: "地図",
    navGet: "ダウンロード",
    kicker: "Mac向け",
    title: "島",
    lede: "島はカメラのところにある。音楽、タイマー、クリップボード。別ウィンドウもDockのアイコンもない。",
    download: "Mac用を入手",
    win: "Windows — 予定",
    hover: "島にポインターを合わせる",
    lidNotch: "ノッチあり",
    lidNone: "ノッチなし",
    mapTitle: "島にあるもの",
    mapLede: "開いた島。すでにあるものへ矢印 — 動画なし。",
    timer: "タイマー",
    timerHow: "左耳：時、分、秒。終わると音と通知。音楽はいったん止まる。",
    edit: "編集",
    editHow: "ノッチ横の鉛筆。余ったボタンはトレイへ。消えない。",
    guide: "ガイド",
    guideHow: `画面上の案内。先になぜ、それからどう使う。${LANGS_ON_SITE}。`,
    clipboard: "クリップボード",
    clipboardHow: "直近の五つのテキスト。行をタップするとまたコピー。",
    media: "メディア",
    mediaHow: "ジャケット、曲名、戻る / 一時停止 / 次へ。音はスピーカー、ヘッドホン、Mac。",
    playlist: "プレイリスト",
    playlistHow: "リストボタンは Music が今のキューを出したときだけ。",
    progress: "進行",
    progressHow: "下のバー。ドラッグで飛ばせる。",
    anim: "アニメーション",
    animHow: "トレイの火花。そこで入れると、一時停止とスキップが光る。",
    hoverWhy: "ホバー、クリックではない",
    hoverBody: "カーソルが島の上にあるときだけ開く。素早く通りすぎるだけでは開かない。約 0.1 秒止まって。ゆっくりなら先にガラスに隙間、カメラの近くで大きく。",
    moveWhy: "移動",
    moveBody: "一秒半で三回クリック — 島がカーソルについて端に付く。カメラ横のボタンで戻る。",
    moveTitle: "移動",
    moveLede: "ホバーではない。一秒半で三回クリックすると、島がカーソルについて端に付く。横はカード、下はピル。カメラのそばにホームボタン。タップで帰る。",
    moveHouse: "ホーム",
    moveSide: "横",
    moveBottom: "下",
    moveClicks: "三回クリック",
    micWhy: "Mac全体のマイク",
    micBody: "タップ一つで入力を切る。ZoomもDiscordも。白は聞こえる。白地に赤は聞こえない。",
    lyricsWhy: "歌詞は横で",
    lyricsBody: "歌詞は島に入らない。吹き出しでガラスのパネルが開く。動かせて、角を引ける。",
    lyricsTitle: "字幕",
    lyricsLede: "歌詞は島に入らない。吹き出しで横にガラスのパネルが開く。つかむのはガラスそのもの。閉じるボタンでも、角の白い点でもない。",
    lyricsGrab: "ここをつかむ",
    lyricsCorner: "角 — サイズ",
    editWhy: "自分の並び",
    editBody: "全部のボタンが要る人ばかりではない。鉛筆でトレイ：載せる、外す、完了。",
    editTitle: "編集",
    editLede: "鉛筆は右耳、ノッチの横。使わないボタンはトレイへ。消えない。トレイのチップをタップすると島に戻る。Done、またはもう一度鉛筆で終わる。メディアとノッチは外せない。",
    editTrayLab: "トレイ",
    getTitle: "Macでは無料",
    getBody: "macOS 14以降。App Storeではない。ディスクイメージ。ダウンロード後、聞かれたら右クリック → 開く。",
    reqs: "ジャケットと再生は Music か Spotify から。",
    donate: "寄付のリンクができたらここに置く。",
    partner: "提携 — このページにフォームはない。",
    privacy: "プライバシー",
    missing: "ビルドはまだ downloads/Island.dmg にない。",
    song: "Night Harbor",
    artist: "Local",
    allOn: "All on the island",
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
  const slot = document.querySelector(".island-slot");
  const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s) % 60).padStart(2, "0")}`;
  const pad = (n) => String(n).padStart(2, "0");

  const syncSlot = () => {
    if (!slot) return;
    const open = island.classList.contains("is-open");
    slot.classList.toggle("is-wide", open);
    slot.classList.toggle("is-taller", open && island.classList.contains("is-tall"));
  };

  const open = () => {
    clearTimeout(closeTimer);
    island.classList.add("is-open");
    syncSlot();
  };
  const close = () => {
    island.classList.remove("is-open");
    syncSlot();
  };

  island.addEventListener("pointerenter", () => {
    clearTimeout(closeTimer);
    clearTimeout(openTimer);
    openTimer = setTimeout(open, 100);
  });
  island.addEventListener("pointerdown", () => {
    clearTimeout(openTimer);
    open();
  });
  wrap.addEventListener("pointerleave", () => {
    clearTimeout(openTimer);
    closeTimer = setTimeout(close, 180);
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
    if (btn.dataset.act === "lyrics") togglePanel("show-lyrics");
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

function glyphBox(root) {
  const box = { left: Infinity, right: -Infinity, top: Infinity, bottom: -Infinity };
  const add = (r) => {
    if (!r.width || !r.height) return;
    box.left = Math.min(box.left, r.left);
    box.right = Math.max(box.right, r.right);
    box.top = Math.min(box.top, r.top);
    box.bottom = Math.max(box.bottom, r.bottom);
  };
  const walk = (node) => {
    if (node.nodeType === Node.TEXT_NODE) {
      if (!node.textContent.trim()) return;
      const range = document.createRange();
      range.selectNodeContents(node);
      [...range.getClientRects()].forEach(add);
      return;
    }
    node.childNodes.forEach(walk);
  };
  walk(root);
  if (!Number.isFinite(box.left)) {
    const r = root.getBoundingClientRect();
    return { left: r.left, right: r.right, top: r.top, bottom: r.bottom };
  }
  return box;
}

function leaders() {
  const svg = document.querySelector(".leaders");
  const chart = document.querySelector(".chart");
  if (!svg || !chart || window.matchMedia("(max-width: 900px)").matches) return;

  const island = chart.querySelector(".chart-island .island");
  if (!island) return;
  const root = chart.getBoundingClientRect();
  const box = island.getBoundingClientRect();
  const w = chart.clientWidth;
  const h = chart.clientHeight;
  const x = (n) => ((n - root.left) / root.width) * w;
  const y = (n) => ((n - root.top) / root.height) * h;

  const spark = chart.querySelector("[data-spot='anim']");
  const sparkBox = spark ? spark.getBoundingClientRect() : null;

  const targets = {
    timer: { x: box.left + 36, y: box.top + 18 },
    edit: { x: box.right - 96, y: box.top + 16 },
    guide: { x: box.right - 70, y: box.top + 16 },
    clipboard: { x: box.right - 18, y: box.top + 16 },
    media: { x: box.left + 48, y: box.top + 62 },
    playlist: { x: box.right - 28, y: box.top + 62 },
    progress: { x: box.left + 140, y: box.bottom - 12 },
    anim: sparkBox
      ? { x: sparkBox.left + sparkBox.width / 2, y: sparkBox.top + sparkBox.height / 2 }
      : { x: box.left + box.width / 2 - 90, y: box.bottom + 34 },
  };

  svg.setAttribute("width", String(w));
  svg.setAttribute("height", String(h));
  svg.setAttribute("viewBox", `0 0 ${w} ${h}`);
  svg.setAttribute("preserveAspectRatio", "none");
  svg.innerHTML = "";
  document.querySelectorAll(".chart .label").forEach((label) => {
    const spot = label.dataset.spot;
    const to = targets[spot];
    if (!to) return;
    const right = label.classList.contains("end");
    const title = label.querySelector("strong") || label;
    const ink = glyphBox(title);
    const gap = 2;
    const fromX = right ? ink.left - gap : ink.right + gap;
    const fromY = (ink.top + ink.bottom) / 2;
    const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
    line.setAttribute("x1", String(x(fromX)));
    line.setAttribute("y1", String(y(fromY)));
    line.setAttribute("x2", String(x(to.x)));
    line.setAttribute("y2", String(y(to.y)));
    svg.appendChild(line);
  });
}

async function downloadGuard() {
  const links = document.querySelectorAll('a.download[href$="Island.dmg"]');
  const note = document.querySelector(".note");
  let ok = false;
  try {
    const res = await fetch("downloads/Island.dmg", { method: "HEAD" });
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

let riseOn = false;

function initRise() {
  const nodes = document.querySelectorAll(".rise, .rise-stay");
  if (!nodes.length || riseOn) return;
  riseOn = true;
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    nodes.forEach((node) => node.classList.add("is-in"));
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        entry.target.classList.toggle("is-in", entry.isIntersecting);
      });
      window.requestAnimationFrame(leaders);
      window.setTimeout(leaders, 780);
    },
    { threshold: 0.16, rootMargin: "0px 0px -8% 0px" }
  );
  nodes.forEach((node) => io.observe(node));
}

function playGate() {
  const body = document.body;
  const gate = document.getElementById("gate");
  const veil = gate && gate.querySelector(".gate-veil");
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const timers = [];
  const later = (fn, ms) => {
    const id = setTimeout(fn, ms);
    timers.push(id);
    return id;
  };

  const done = () => {
    if (body.classList.contains("is-ready")) return;
    timers.forEach(clearTimeout);
    goDark();
    body.classList.add("is-night", "is-ready");
    body.classList.remove("booting");
    if (gate) gate.remove();
    initRise();
    window.requestAnimationFrame(leaders);
  };

  if (reduce || !gate || !veil) {
    done();
    return;
  }

  const expandNight = (ms) =>
    new Promise((resolve) => {
      const start = performance.now();
      const from = parseFloat(getComputedStyle(veil).getPropertyValue("--hole")) || 170;
      const max = Math.hypot(window.innerWidth, window.innerHeight) * 1.2;
      const ease = (t) => 1 - Math.pow(1 - t, 4);
      const frame = (now) => {
        const t = Math.min(1, (now - start) / ms);
        veil.style.setProperty("--hole", `${from + (max - from) * ease(t)}px`);
        if (t < 1) requestAnimationFrame(frame);
        else resolve();
      };
      requestAnimationFrame(frame);
    });

  gate.addEventListener("click", done);
  window.addEventListener(
    "keydown",
    (event) => {
      if (event.key === "Escape" || event.key === "Enter") done();
    },
    { once: true }
  );

  later(() => {
    goDark();
    body.classList.add("is-night");
    initRise();
    expandNight(720).then(() => {
      if (body.classList.contains("is-ready")) return;
      gate.classList.add("is-done");
      later(() => {
        if (body.classList.contains("is-ready")) return;
        body.classList.add("is-ready");
        body.classList.remove("booting");
        gate.remove();
        window.requestAnimationFrame(leaders);
      }, 280);
    });
  }, 60);
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
  const [gx, gy] = tipOn(card, card, 0.5, 0.28);
  const ax = gx + 28;
  const ay = gy + 56;
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
  const [mx, my] = mic ? tipOn(mic, origin, 0.45, 0.4) : [px + 40, py];
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
window.addEventListener("load", leaders);
window.addEventListener("resize", () => {
  window.requestAnimationFrame(leaders);
});
