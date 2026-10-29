import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../main.dart';
import '../ui.dart';

enum ExerciseType { sentenceBuilder, fillBlank, tenseCheck }

class GrammarExercise {
  const GrammarExercise({
    required this.type,
    required this.prompt,
    this.subprompt,
    this.tokens = const [],
    required this.solution,
    this.options = const [],
    required this.explanation,
  });

  final ExerciseType type;
  final String prompt;
  final String? subprompt;
  final List<String> tokens;
  final dynamic solution; // List<String> for sentenceBuilder, String for choice
  final List<String> options;
  final String explanation;
}

class GrammarExample {
  const GrammarExample({required this.fr, required this.pt, this.note});
  final String fr;
  final String pt;
  final String? note;
}

class GrammarSection {
  const GrammarSection({required this.title, required this.content, this.callout});
  final String title;
  final String content;
  final String? callout;
}

class GrammarTopic {
  const GrammarTopic({
    required this.id,
    required this.title,
    required this.level,
    required this.icon,
    required this.summary,
    required this.sections,
    required this.examples,
    required this.exercises,
  });

  final String id;
  final String title;
  final String level;
  final IconData icon;
  final String summary;
  final List<GrammarSection> sections;
  final List<GrammarExample> examples;
  final List<GrammarExercise> exercises;
}

final grammarTopics = <GrammarTopic>[
  const GrammarTopic(
    id: 'order_negation',
    title: 'Ordem da Frase e Negação',
    level: 'A1',
    icon: CupertinoIcons.arrow_right_arrow_left,
    summary: 'Sujeito obrigatório e a fórmula sanduíche ne... pas.',
    sections: [
      GrammarSection(
        title: '1. O sujeito é sempre obrigatório',
        content:
            'Em português você pode ocultar o sujeito: "Falo francês", "Choveu".\n'
            'Em francês, o pronome sujeito é OBRIGATÓRIO em todas as frases:\n'
            '• Je parle français (Eu falo francês)\n'
            '• Il pleut (Chove)\n'
            'Nunca diga apenas "Parle français", sempre diga "Je parle français".',
      ),
      GrammarSection(
        title: '2. A fórmula sanduíche: ne + verbo + pas',
        content:
            'Para transformar qualquer frase afirmativa em negativa, abraçamos o verbo conjugado como um sanduíche:\n\n'
            '  [ Sujeito ] + ne + [ Verbo ] + pas + [ Resto ]\n\n'
            'Se o verbo começar com vogal ou "h" mudo, o "ne" vira "n\'":\n'
            '• J\'aime le café → Je n\'aime pas le café.',
        callout: 'Dica do dia a dia: Na França falada informal, os nativos costumam engolir o "ne" e dizer apenas "Je sais pas", mas na escrita e no padrão o "ne ... pas" é essencial!',
      ),
    ],
    examples: [
      GrammarExample(fr: 'Je parle français.', pt: 'Eu falo francês.', note: 'Afirmativa'),
      GrammarExample(fr: 'Je ne parle pas anglais.', pt: 'Eu não falo inglês.', note: 'Negação regular'),
      GrammarExample(fr: 'Il comprend la question.', pt: 'Ele entende a pergunta.', note: 'Afirmativa'),
      GrammarExample(fr: 'Il ne comprend pas la question.', pt: 'Ele não entende a pergunta.', note: 'Negação regular'),
      GrammarExample(fr: 'Elle aime le café.', pt: 'Ela gosta de café.', note: 'Afirmativa com vogal'),
      GrammarExample(fr: "Elle n'aime pas le thé.", pt: 'Ela não gosta de chá.', note: "n' antes de vogal"),
    ],
    exercises: [
      GrammarExercise(
        type: ExerciseType.sentenceBuilder,
        prompt: 'Monte a frase negativa correspondente:',
        subprompt: 'Eu não falo inglês.',
        tokens: ['Je', 'ne', 'parle', 'pas', 'anglais'],
        solution: ['Je', 'ne', 'parle', 'pas', 'anglais'],
        explanation: 'Muito bem! Sujeito (Je) + ne + verbo (parle) + pas + complemento (anglais).',
      ),
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Complete a negação antes da vogal:',
        subprompt: 'Elle ___ aime ___ le froid. (Ela não gosta de frio)',
        options: ["n' ... pas", 'ne ... pas', 'pas ... ne'],
        solution: "n' ... pas",
        explanation: 'Excelente! Como "aime" começa com vogal, o "ne" vira "n\'".',
      ),
      GrammarExercise(
        type: ExerciseType.sentenceBuilder,
        prompt: 'Monte a frase negativa:',
        subprompt: 'Nós não entendemos.',
        tokens: ['Nous', 'ne', 'comprenons', 'pas'],
        solution: ['Nous', 'ne', 'comprenons', 'pas'],
        explanation: 'Perfeito! "Nous ne comprenons pas" segue a estrutura clássica sanduíche.',
      ),
    ],
  ),
  const GrammarTopic(
    id: 'questions',
    title: 'Como Fazer Perguntas',
    level: 'A1',
    icon: CupertinoIcons.question_circle,
    summary: 'Os 3 jeitos reais de perguntar e palavras interrogativas.',
    sections: [
      GrammarSection(
        title: 'Os 3 jeitos de fazer uma pergunta',
        content:
            'Você quer perguntar "Você vem?":\n'
            '1. Pela entonação (o mais comum no dia a dia):\n'
            '   "Tu viens ?" (mesma ordem da afirmativa, voz sobe no final).\n\n'
            '2. Com a fórmula "Est-ce que" (neutro, coringa para qualquer situação):\n'
            '   "Est-ce que tu viens ?" (basta colocar Est-ce que na frente!).\n\n'
            '3. Por inversão verbo-sujeito (formal / literário):\n'
            '   "Viens-tu ?"',
      ),
      GrammarSection(
        title: 'Palavras interrogativas essenciais',
        content:
            'Para perguntas abertas, basta colocar a palavra interrogativa antes de "est-ce que":\n'
            '• Où (Onde) → Où est-ce que tu habites ?\n'
            '• Quand (Quando) → Quand est-ce qu\'il arrive ?\n'
            '• Comment (Como) → Comment est-ce que tu t\'appelles ?\n'
            '• Pourquoi (Por que) → Pourquoi est-ce que tu apprends le français ?\n'
            '• Qu\'est-ce que (O que) → Qu\'est-ce que tu fais ?',
        callout: 'Coringa: "Est-ce que" não tem tradução literal própria — funciona como um ponto de interrogação falado!',
      ),
    ],
    examples: [
      GrammarExample(fr: 'Tu as faim ?', pt: 'Você está com fome?', note: 'Informal / entonação'),
      GrammarExample(fr: 'Est-ce que tu as faim ?', pt: 'Você está com fome?', note: 'Fórmula coringa'),
      GrammarExample(fr: 'Où habitez-vous ?', pt: 'Onde o senhor mora?', note: 'Où = onde'),
      GrammarExample(fr: 'Pourquoi est-ce que tu ris ?', pt: 'Por que você está rindo?', note: 'Pourquoi = por que'),
      GrammarExample(fr: "Qu'est-ce que c'est ?", pt: 'O que é isso?', note: "Qu'est-ce que = o que"),
    ],
    exercises: [
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Qual palavra interrogativa significa "Onde"?',
        subprompt: '___ habitez-vous ? (Onde vocês moram?)',
        options: ['Où', 'Quand', 'Pourquoi', 'Comment'],
        solution: 'Où',
        explanation: 'Exato! "Où" significa "onde" (não confunda com "ou" sem acento, que significa "ou").',
      ),
      GrammarExercise(
        type: ExerciseType.sentenceBuilder,
        prompt: 'Monte a pergunta usando a fórmula coringa:',
        subprompt: 'Você tem fome? / Você está com fome?',
        tokens: ['Est-ce', 'que', 'tu', 'as', 'faim', '?'],
        solution: ['Est-ce', 'que', 'tu', 'as', 'faim', '?'],
        explanation: 'Brilhante! "Est-ce que tu as faim ?" é natural e perfeitamente compreensível.',
      ),
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Complete a pergunta de "O que você faz?":',
        subprompt: '___ fais-tu ?',
        options: ['Que', 'Où', 'Pourquoi'],
        solution: 'Que',
        explanation: 'Correto! Na inversão formal usa-se "Que fais-tu ?", ou no dia a dia "Qu\'est-ce que tu fais ?".',
      ),
    ],
  ),
  const GrammarTopic(
    id: 'four_pillars',
    title: 'Os 4 Verbos Pilares',
    level: 'A1',
    icon: CupertinoIcons.flame,
    summary: 'Être, avoir, aller, faire e as pegadinhas com português.',
    sections: [
      GrammarSection(
        title: '1. Être (Ser / Estar) e Avoir (Ter)',
        content:
            '• Être: je suis, tu es, il/elle est, nous sommes, vous êtes, ils/elles sont.\n'
            '• Avoir: j\'ai, tu as, il/elle a, nous avons, vous avez, ils/elles ont.\n\n'
            'PEGADINHA CRUCIAL COM PORTUGUÊS:\n'
            'Em português dizemos "Eu tenho 20 anos" (ter) e "Estou com fome / sede / medo" (estar).\n'
            'Em francês, TUDO isso usa AVOIR (ter)!\n'
            '• J\'ai 25 ans (tenho 25 anos)\n'
            '• J\'ai faim (estou com fome)\n'
            '• J\'ai soif (estou com sede)\n'
            '• J\'ai chaud / froid (estou com calor / frio)\n'
            '• J\'ai peur (estou com medo)',
        callout: 'Nunca diga "Je suis faim" (significaria "eu sou fome"). Sempre diga "J\'ai faim"!',
      ),
      GrammarSection(
        title: '2. Aller (Ir) e Faire (Fazer)',
        content:
            '• Aller: je vais, tu vas, il va, nous allons, vous allez, ils vont.\n'
            '  Aller + infinitivo forma o FUTURO IMEDIATO: "Je vais manger" (vou comer).\n\n'
            '• Faire: je fais, tu fais, il fait, nous faisons, vous faites, ils font.\n'
            '  Faire é usado para o clima: "Il fait beau" (está bonito o tempo), "Il fait froid" (está frio).',
      ),
    ],
    examples: [
      GrammarExample(fr: 'Je suis brésilien.', pt: 'Eu sou brasileiro.', note: 'Être'),
      GrammarExample(fr: "J'ai faim et j'ai 20 ans.", pt: 'Estou com fome e tenho 20 anos.', note: 'Avoir para sensações e idade'),
      GrammarExample(fr: 'Nous allons au restaurant.', pt: 'Nós vamos ao restaurante.', note: 'Aller'),
      GrammarExample(fr: 'Je vais partir demain.', pt: 'Eu vou partir amanhã.', note: 'Aller + infinitivo (futuro)'),
      GrammarExample(fr: "Il fait beau aujourd'hui.", pt: 'Está bonito o dia hoje.', note: 'Faire para o tempo climático'),
    ],
    exercises: [
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Qual o verbo correto para dizer a idade?',
        subprompt: "J'___ 28 ans. (Eu tenho 28 anos)",
        options: ['ai', 'suis', 'vais', 'fais'],
        solution: 'ai',
        explanation: 'Perfeito! Idade em francês sempre se conjuga com AVOIR (J\'ai ... ans).',
      ),
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Como se diz "estou com calor"?',
        subprompt: "J'___ chaud.",
        options: ['ai', 'suis', 'fais', 'vais'],
        solution: 'ai',
        explanation: 'Muito bem! "Avoir chaud", "avoir faim", "avoir soif" usam todos o verbo avoir.',
      ),
      GrammarExercise(
        type: ExerciseType.sentenceBuilder,
        prompt: 'Monte a frase do futuro imediato:',
        subprompt: 'Eu vou comer agora.',
        tokens: ['Je', 'vais', 'manger', 'maintenant'],
        solution: ['Je', 'vais', 'manger', 'maintenant'],
        explanation: 'Correto! Verbo aller conjugado (vais) + infinitivo (manger).',
      ),
    ],
  ),
  const GrammarTopic(
    id: 'regular_verbs',
    title: 'Conjugação Regular e o Som Mudo',
    level: 'A1',
    icon: CupertinoIcons.speaker_2,
    summary: 'O segredo de ouro: -e, -es, -ent soam exatamente iguais.',
    sections: [
      GrammarSection(
        title: 'O grande segredo do áudio nos verbos em -ER',
        content:
            'Cerca de 80% dos verbos franceses terminam em -ER (parler, aimer, habiter, travailler).\n'
            'Na escrita eles mudam, mas no ÁUDIO acontecem coisas incríveis:\n\n'
            '• Je parle  → som: /paʁl/\n'
            '• Tu parles → som: /paʁl/\n'
            '• Il parle  → som: /paʁl/\n'
            '• Ils parlent → som: /paʁl/ (o "-ent" é totalmente mudo!)\n\n'
            'Ou seja: 4 das 6 pessoas soam EXATAMENTE IGUAIS no presente!\n'
            'As únicas que soam diferentes são:\n'
            '• Nous parlons (/paʁ.lɔ̃/)\n'
            '• Vous parlez (/paʁ.le/)',
        callout: 'Não pronuncie o "-ent" no final dos verbos em 3ª pessoa do plural! "Ils parlent" soa idêntico a "Il parle"!',
      ),
      GrammarSection(
        title: 'Terminações regulares resumidas',
        content:
            'Verbos em -ER: radical + -e, -es, -e, -ons, -ez, -ent.\n'
            'Verbos em -IR (finir): je finis, tu finis, il finit, nous finissons, vous finissez, ils finissent.\n'
            'Verbos em -RE (attendre): j\'attends, tu attends, il attend, nous attendons, vous attendez, ils attendent.',
      ),
    ],
    examples: [
      GrammarExample(fr: 'Je parle portugais.', pt: 'Eu falo português.', note: 'Final -e mudo'),
      GrammarExample(fr: 'Tu habites à Paris.', pt: 'Você mora em Paris.', note: 'Final -es mudo'),
      GrammarExample(fr: 'Ils travaillent beaucoup.', pt: 'Eles trabalham muito.', note: 'Final -ent mudo!'),
      GrammarExample(fr: 'Nous habitons ici.', pt: 'Nós moramos aqui.', note: '-ons audível'),
      GrammarExample(fr: 'Vous parlez vite.', pt: 'Vocês falam rápido.', note: '-ez soa /é/'),
    ],
    exercises: [
      GrammarExercise(
        type: ExerciseType.tenseCheck,
        prompt: 'Quantas dessas formas soam idênticas no áudio: je parle, tu parles, il parle, ils parlent?',
        options: ['Todas as 4', 'Apenas 2', 'Nenhuma'],
        solution: 'Todas as 4',
        explanation: 'Exato! As terminações -e, -es, e -ent são todas mudas, então soam idênticas /paʁl/!',
      ),
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Qual a conjugação correta para "elles"?',
        subprompt: 'Elles ___ le français. (parler)',
        options: ['parlent', 'parlons', 'parlez', 'parle'],
        solution: 'parlent',
        explanation: 'Excelente! A 3ª pessoa do plural recebe a terminação escrita -ent (muda na fala).',
      ),
      GrammarExercise(
        type: ExerciseType.sentenceBuilder,
        prompt: 'Monte a frase com o verbo regular:',
        subprompt: 'Nós moramos em Paris.',
        tokens: ['Nous', 'habitons', 'à', 'Paris'],
        solution: ['Nous', 'habitons', 'à', 'Paris'],
        explanation: 'Perfeito! "Nous habitons à Paris".',
      ),
    ],
  ),
  const GrammarTopic(
    id: 'prepositions',
    title: 'Preposições e Contrações',
    level: 'A2',
    icon: CupertinoIcons.map_pin_ellipse,
    summary: 'À, de, en, chez, e as contrações au, du, aux.',
    sections: [
      GrammarSection(
        title: '1. Cidades vs Países (à, en, au, aux)',
        content:
            '• CIDADES: sempre usam "à":\n'
            '  à Paris, à São Paulo, à Lyon, à Tokyo.\n\n'
            '• PAÍSES FEMININOS (terminam em "e") ou que começam por vogal: usam "en":\n'
            '  en France, en Italie, en Espagne, en Suisse, en Argentine.\n\n'
            '• PAÍSES MASCULINOS (a maioria que não termina em "e"): usam "au":\n'
            '  au Brésil, au Canada, au Japon, au Portugal.\n\n'
            '• PAÍSES NO PLURAL: usam "aux":\n'
            '  aux États-Unis, aux Pays-Bas.',
      ),
      GrammarSection(
        title: '2. A preposição mágica "chez"',
        content:
            '"Chez" significa "na casa de", "no consultório de" ou "no trabalho de":\n'
            '• Je rentre chez moi (Estou voltando para minha casa)\n'
            '• Je vais chez le médecin (Vou ao médico / consultório)\n'
            '• Chez Pierre (Na casa do Pierre)\n\n'
            '3. Contrações obrigatórias:\n'
            '• à + le = au (Je vais au cinéma)\n'
            '• à + les = aux (Je parle aux voisins)\n'
            '• de + le = du (Le livre du professeur)\n'
            '• de + les = des (La maison des parents)',
        callout: 'Atenção: "à la" e "de la" NÃO contraem: "à la plage", "de la musique".',
      ),
    ],
    examples: [
      GrammarExample(fr: "J'habite à São Paulo.", pt: 'Eu moro em São Paulo.', note: 'Cidade = à'),
      GrammarExample(fr: 'Elle voyage en France.', pt: 'Ela viaja na/para a França.', note: 'País feminino = en'),
      GrammarExample(fr: 'Il vit au Brésil.', pt: 'Ele vive no Brasil.', note: 'País masculino = au'),
      GrammarExample(fr: 'Nous sommes chez nous.', pt: 'Estamos na nossa casa.', note: 'Chez = casa de'),
      GrammarExample(fr: 'Je vais au marché.', pt: 'Vou ao mercado.', note: 'à + le = au'),
    ],
    exercises: [
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Qual preposição usar para o Brasil?',
        subprompt: "J'habite ___ Brésil.",
        options: ['au', 'en', 'à', 'dans'],
        solution: 'au',
        explanation: 'Correto! Brasil é masculino ("le Brésil"), por isso usamos "au" (à + le).',
      ),
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Qual preposição usar para a França?',
        subprompt: 'Elle va ___ France.',
        options: ['en', 'au', 'à', 'de'],
        solution: 'en',
        explanation: 'Muito bem! "La France" termina em "e", sendo feminino, portanto leva "en France".',
      ),
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Como dizer "na casa do médico / no consultório"?',
        subprompt: 'Je vais ___ le médecin.',
        options: ['chez', 'à', 'dans', 'au'],
        solution: 'chez',
        explanation: 'Exato! Quando o destino é uma pessoa ou profissional, usa-se sempre "chez".',
      ),
    ],
  ),
  const GrammarTopic(
    id: 'simple_tenses',
    title: 'Tempos Verbais Simples',
    level: 'A2',
    icon: CupertinoIcons.clock,
    summary: 'Présent, Passé Composé e Futur Proche no dia a dia.',
    sections: [
      GrammarSection(
        title: 'Os 3 tempos que resolvem 90% da sua comunicação',
        content:
            '1. PRÉSENT (Presente):\n'
            '   Expressa o agora ou rotina: "Je mange une pomme" (Eu como uma maçã).\n\n'
            '2. PASSÉ COMPOSÉ (Passado composto):\n'
            '   Para fatos concluídos no passado. É formado por [ Avoir ou Être ] + [ Particípio ]:\n'
            '   • J\'ai parlé (Eu falei)\n'
            '   • J\'ai mangé (Eu comi)\n'
            '   • J\'ai fini (Eu terminei)\n'
            '   • Je suis allé (Eu fui — verbos de movimento usam être!)\n\n'
            '3. FUTUR PROCHE (Futuro imediato):\n'
            '   O futuro mais usado na língua falada! Formado por [ Aller no presente ] + [ Infinitivo ]:\n'
            '   • Je vais regarder un film (Vou assistir a um filme)\n'
            '   • Nous allons partir (Vamos partir)',
        callout: 'Dica prática: Em vez de decorar o futuro simples literário, use o Futur Proche com "aller + verbo"! É natural e aceito em qualquer conversa.',
      ),
    ],
    examples: [
      GrammarExample(fr: 'Aujourd\'hui, j\'étudie le français.', pt: 'Hoje eu estudo francês.', note: 'Présent'),
      GrammarExample(fr: 'Hier, j\'ai regardé un bon film.', pt: 'Ontem eu assisti a um bom filme.', note: 'Passé Composé (j\'ai regardé)'),
      GrammarExample(fr: 'Demain, je vais voyager.', pt: 'Amanhã eu vou viajar.', note: 'Futur Proche (vais voyager)'),
      GrammarExample(fr: 'Elle est venue hier.', pt: 'Ela veio ontem.', note: 'Passé Composé com être'),
    ],
    exercises: [
      GrammarExercise(
        type: ExerciseType.tenseCheck,
        prompt: 'Em qual tempo verbal está a frase:',
        subprompt: 'Hier soir, nous avons mangé au restaurant.',
        options: ['Passé Composé', 'Présent', 'Futur Proche'],
        solution: 'Passé Composé',
        explanation: 'Exato! "avons mangé" é a estrutura auxiliar (avoir) + particípio (mangé) do Passé Composé.',
      ),
      GrammarExercise(
        type: ExerciseType.tenseCheck,
        prompt: 'Em qual tempo verbal está a frase:',
        subprompt: 'Ce soir, je vais dormir tôt.',
        options: ['Futur Proche', 'Présent', 'Passé Composé'],
        solution: 'Futur Proche',
        explanation: 'Perfeito! "vais dormir" (aller + infinitivo) forma o Futur Proche.',
      ),
      GrammarExercise(
        type: ExerciseType.sentenceBuilder,
        prompt: 'Monte a frase no Passé Composé:',
        subprompt: 'Eu falei com o Pierre.',
        tokens: ["J'ai", 'parlé', 'avec', 'Pierre'],
        solution: ["J'ai", 'parlé', 'avec', 'Pierre'],
        explanation: 'Brilhante! "J\'ai parlé avec Pierre".',
      ),
    ],
  ),
  const GrammarTopic(
    id: 'articles_partitives',
    title: 'Artigos e Partitivos',
    level: 'A2',
    icon: CupertinoIcons.circle_grid_hex,
    summary: 'Du, de la, des e a famosa regra de ouro do "pas de".',
    sections: [
      GrammarSection(
        title: 'O que são artigos partitivos?',
        content:
            'Em português dizemos "Eu bebo café", "Comi pão", sem nenhum artigo.\n'
            'Em francês, é OBRIGATÓRIO usar um partitivo para coisas incontáveis ou porções:\n\n'
            '• Masculino singular: du (de + le)\n'
            '  Je bois du café. / Je mange du pain.\n'
            '• Feminino singular: de la\n'
            '  Je mange de la salade. / J\'écoute de la musique.\n'
            '• Antes de vogal: de l\'\n'
            '  Je bois de l\'eau.\n'
            '• Plural: des\n'
            '  J\'achète des croissants.',
      ),
      GrammarSection(
        title: 'A REGRA DE OURO DA NEGAÇÃO: vira sempre "de"!',
        content:
            'Quando a frase se torna negativa, TODOS os partitivos (du, de la, de l\', des) e até os artigos indefinidos (un, une) são substituídos por apenas "de" (ou "d\'")!\n\n'
            '• Je bois du café → Je ne bois pas DE café.\n'
            '• J\'ai une voiture → Je n\'ai pas DE voiture.\n'
            '• Il mange des pommes → Il ne mange pas DE pommes.',
        callout: 'Memorize: Negação com pas + de (pas de café, pas de problème, pas de sucre)!',
      ),
    ],
    examples: [
      GrammarExample(fr: 'Je bois du café tous les matins.', pt: 'Eu bebo café toda manhã.', note: 'Partitivo masculino: du'),
      GrammarExample(fr: "Je ne bois pas de café.", pt: 'Eu não bebo café.', note: 'Regra de ouro: pas de'),
      GrammarExample(fr: "Je bois de l'eau fraîche.", pt: 'Eu bebo água fresca.', note: "Antes de vogal: de l'"),
      GrammarExample(fr: "Il n'y a pas de problème.", pt: 'Não há problema.', note: 'Famoso "pas de problème"'),
      GrammarExample(fr: 'Elle mange de la confiture.', pt: 'Ela come geleia.', note: 'Partitivo feminino: de la'),
    ],
    exercises: [
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Qual partitivo usar para café (masculino incontável)?',
        subprompt: 'Je veux ___ café, s\'il vous plaît.',
        options: ['du', 'de la', 'le', 'un'],
        solution: 'du',
        explanation: 'Muito bem! Café é masculino incontável, logo usamos "du café".',
      ),
      GrammarExercise(
        type: ExerciseType.fillBlank,
        prompt: 'Aplique a regra de ouro da negação:',
        subprompt: 'Je ne bois pas ___ café.',
        options: ['de', 'du', 'le', 'un'],
        solution: 'de',
        explanation: 'Exato! Na negação com "pas", os partitivos (du, de la, des) viram invariavelmente "de".',
      ),
      GrammarExercise(
        type: ExerciseType.sentenceBuilder,
        prompt: 'Monte a expressão clássica em francês:',
        subprompt: 'Não há problema. / Sem problemas.',
        tokens: ['Il', "n'y", 'a', 'pas', 'de', 'problème'],
        solution: ['Il', "n'y", 'a', 'pas', 'de', 'problème'],
        explanation: 'Perfeito! "Il n\'y a pas de problème" — ou simplesmente "pas de problème"!',
      ),
    ],
  ),
];

final _tts = FlutterTts()..setLanguage('fr-FR')..setSpeechRate(0.46);
void _speak(String text) => _tts.speak(text);

/// Main Grammar screen listing the 7 practical grammar modules.
class GrammarScreen extends StatelessWidget {
  const GrammarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final done = store.grammarDone;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(T.s4, T.s4, T.s4, T.s2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Gramática Prática', style: T.largeTitle),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: T.s3, vertical: T.s1),
                              decoration: BoxDecoration(
                                color: done.length == grammarTopics.length
                                    ? T.mint
                                    : T.lavender,
                                borderRadius: BorderRadius.circular(T.rSm),
                              ),
                              child: Text(
                                '${done.length}/${grammarTopics.length} concluídos',
                                style: T.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: T.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: T.s1),
                        Text(
                          'Domine a estrutura real do francês sem decoreba e com exercícios interativos.',
                          style: T.secondary,
                        ),
                        const SizedBox(height: T.s4),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(T.s4, 0, T.s4, 96),
                  sliver: SliverList.builder(
                    itemCount: grammarTopics.length,
                    itemBuilder: (context, idx) {
                      final topic = grammarTopics[idx];
                      final isDone = done.contains(topic.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: T.s3),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => LessonScreen(topic: topic),
                              ),
                            );
                          },
                          child: GlassCard(
                            color: isDone ? T.mint.withValues(alpha: 0.35) : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDone ? T.mint : T.lavender,
                                    borderRadius: BorderRadius.circular(T.rMd),
                                  ),
                                  child: Icon(
                                    isDone
                                        ? CupertinoIcons.check_mark
                                        : topic.icon,
                                    color: T.text,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: T.s3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          LevelChip(topic.level),
                                          const SizedBox(width: T.s2),
                                          Expanded(
                                            child: Text(
                                              topic.title,
                                              style: T.body.copyWith(
                                                  fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: T.s1),
                                      Text(
                                        topic.summary,
                                        style: T.caption,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: T.s2),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  color: isDone ? T.text : T.textMuted,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Detailed Lesson Screen with clear explanations, audio examples, and interactive quiz.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.topic});
  final GrammarTopic topic;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _activeExercise = 0;
  List<String> _builderSelected = [];
  List<String> _builderAvailable = [];
  String? _selectedOption;
  bool? _isCorrect;
  String _feedbackMessage = '';
  bool _quizFinished = false;

  @override
  void initState() {
    super.initState();
    _resetCurrentExercise();
  }

  void _resetCurrentExercise() {
    _isCorrect = null;
    _feedbackMessage = '';
    _selectedOption = null;
    final ex = widget.topic.exercises[_activeExercise];
    if (ex.type == ExerciseType.sentenceBuilder) {
      _builderSelected = [];
      _builderAvailable = List<String>.from(ex.tokens)..shuffle();
    }
  }

  void _checkExercise() {
    final ex = widget.topic.exercises[_activeExercise];
    bool correct = false;

    if (ex.type == ExerciseType.sentenceBuilder) {
      final target = (ex.solution as List<String>).join(' ');
      final chosen = _builderSelected.join(' ');
      correct = (chosen.toLowerCase().trim() == target.toLowerCase().trim());
    } else {
      correct = (_selectedOption == ex.solution);
    }

    setState(() {
      _isCorrect = correct;
      if (correct) {
        _feedbackMessage = ex.explanation;
      } else {
        _feedbackMessage = 'Ainda não está certo. Tente novamente!';
      }
    });
  }

  void _nextExercise() {
    if (_activeExercise + 1 < widget.topic.exercises.length) {
      setState(() {
        _activeExercise++;
        _resetCurrentExercise();
      });
    } else {
      setState(() {
        _quizFinished = true;
      });
      store.markGrammarDone(widget.topic.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.topic;
    final exercises = t.exercises;
    final isDone = store.grammarDone.contains(t.id);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: T.s3, vertical: T.s2),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: T.surface,
                        borderRadius: BorderRadius.circular(T.rMd),
                        border: Border.all(color: T.hairline, width: 0.5),
                      ),
                      child: const Icon(CupertinoIcons.back,
                          color: T.text, size: 20),
                    ),
                  ),
                  const SizedBox(width: T.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title,
                            style: T.body.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        Text('Tópico ${t.level}', style: T.caption),
                      ],
                    ),
                  ),
                  if (isDone || _quizFinished)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: T.s2, vertical: 3),
                      decoration: BoxDecoration(
                        color: T.mint,
                        borderRadius: BorderRadius.circular(T.rSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.check_mark,
                              size: 14, color: T.text),
                          const SizedBox(width: 3),
                          Text('Concluído',
                              style: T.caption.copyWith(
                                  fontWeight: FontWeight.w700, color: T.text)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Body Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(T.s4, T.s2, T.s4, T.s6),
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                children: [
                  // Explanations
                  for (final sec in t.sections) ...[
                    Text(sec.title,
                        style: T.title.copyWith(fontSize: 18)),
                    const SizedBox(height: T.s2),
                    GlassCard(
                      child: Text(sec.content,
                          style: T.body.copyWith(height: 1.45)),
                    ),
                    if (sec.callout != null) ...[
                      const SizedBox(height: T.s2),
                      Container(
                        padding: const EdgeInsets.all(T.s3),
                        decoration: BoxDecoration(
                          color: T.butter.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(T.rMd),
                          border: Border.all(color: T.hairline, width: 0.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(CupertinoIcons.lightbulb,
                                size: 18, color: T.text),
                            const SizedBox(width: T.s2),
                            Expanded(
                              child: Text(sec.callout!,
                                  style: T.secondary.copyWith(
                                      color: T.text, height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: T.s4),
                  ],

                  // Audio Examples Section
                  Text('Exemplos com Áudio',
                      style: T.title.copyWith(fontSize: 18)),
                  const SizedBox(height: T.s2),
                  GlassCard(
                    padding: const EdgeInsets.all(T.s2),
                    child: Column(
                      children: [
                        for (int i = 0; i < t.examples.length; i++) ...[
                          if (i > 0)
                            const Divider(
                                height: 1, color: T.hairline, indent: 8, endIndent: 8),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: T.s3, vertical: 2),
                            title: Text(t.examples[i].fr,
                                style: T.body.copyWith(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.examples[i].pt, style: T.secondary),
                                if (t.examples[i].note != null)
                                  Text(t.examples[i].note!,
                                      style: T.caption
                                          .copyWith(color: T.textMuted)),
                              ],
                            ),
                            trailing: GestureDetector(
                              onTap: () => _speak(t.examples[i].fr),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: T.sky.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.speaker_2,
                                    size: 18, color: T.text),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s5),

                  // Interactive Exercises Header
                  Row(
                    children: [
                      const Icon(CupertinoIcons.bolt_fill,
                          color: T.text, size: 20),
                      const SizedBox(width: T.s2),
                      Expanded(
                        child: Text('Exercícios da Aula',
                            style: T.title.copyWith(fontSize: 18)),
                      ),
                      if (!_quizFinished)
                        Text(
                          '${_activeExercise + 1} de ${exercises.length}',
                          style: T.caption.copyWith(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: T.s2),

                  // Exercises Area
                  if (_quizFinished)
                    _buildCelebrationCard(context)
                  else
                    _buildQuizCard(exercises[_activeExercise]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationCard(BuildContext context) {
    return GlassCard(
      color: T.mint.withValues(alpha: 0.5),
      child: Column(
        children: [
          const SizedBox(height: T.s2),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: T.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.checkmark_seal_fill,
                size: 32, color: T.text),
          ),
          const SizedBox(height: T.s3),
          Text('Bravo ! Aula Concluída',
              style: T.title.copyWith(fontSize: 20)),
          const SizedBox(height: T.s1),
          Text(
            'Você dominou os conceitos e exercícios deste tópico com sucesso!',
            style: T.secondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: T.s4),
          PillButton(
            'Voltar aos Tópicos',
            icon: CupertinoIcons.arrow_left,
            color: T.lavender,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(GrammarExercise ex) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ex.prompt,
              style: T.body.copyWith(fontWeight: FontWeight.w600)),
          if (ex.subprompt != null) ...[
            const SizedBox(height: T.s1),
            Text(ex.subprompt!, style: T.secondary),
          ],
          const SizedBox(height: T.s4),

          // Exercise Type Specific UI
          if (ex.type == ExerciseType.sentenceBuilder) ...[
            // Active Answer Target Area
            Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.all(T.s2),
              decoration: BoxDecoration(
                color: T.bg,
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: T.hairline, width: 0.8),
              ),
              child: _builderSelected.isEmpty
                  ? Center(
                      child: Text('Toque nas palavras abaixo para montar a frase',
                          style: T.caption))
                  : Wrap(
                      spacing: T.s2,
                      runSpacing: T.s2,
                      children: [
                        for (int i = 0; i < _builderSelected.length; i++)
                          GestureDetector(
                            onTap: _isCorrect == true
                                ? null
                                : () {
                                    setState(() {
                                      final word =
                                          _builderSelected.removeAt(i);
                                      _builderAvailable.add(word);
                                      _isCorrect = null;
                                    });
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: T.s3, vertical: T.s2),
                              decoration: BoxDecoration(
                                color: T.lavender,
                                borderRadius: BorderRadius.circular(T.rSm),
                                border:
                                    Border.all(color: T.hairline, width: 0.5),
                              ),
                              child: Text(_builderSelected[i],
                                  style: T.body.copyWith(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: T.s3),
            // Available Word Chips
            Wrap(
              spacing: T.s2,
              runSpacing: T.s2,
              children: [
                for (int i = 0; i < _builderAvailable.length; i++)
                  GestureDetector(
                    onTap: _isCorrect == true
                        ? null
                        : () {
                            setState(() {
                              final word = _builderAvailable.removeAt(i);
                              _builderSelected.add(word);
                              _isCorrect = null;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: T.s3, vertical: T.s2),
                      decoration: BoxDecoration(
                        color: T.surface,
                        borderRadius: BorderRadius.circular(T.rSm),
                        border: Border.all(color: T.hairline, width: 0.5),
                      ),
                      child: Text(_builderAvailable[i], style: T.body),
                    ),
                  ),
              ],
            ),
          ] else ...[
            // Multiple Choice Options
            for (final opt in ex.options) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: T.s2),
                child: GestureDetector(
                  onTap: _isCorrect == true
                      ? null
                      : () {
                          setState(() {
                            _selectedOption = opt;
                            _isCorrect = null;
                          });
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: T.s3, vertical: T.s3),
                    decoration: BoxDecoration(
                      color: _selectedOption == opt
                          ? (_isCorrect == true
                              ? T.mint
                              : (_isCorrect == false ? T.rose : T.lavender))
                          : T.surface,
                      borderRadius: BorderRadius.circular(T.rMd),
                      border: Border.all(
                        color: _selectedOption == opt ? T.text : T.hairline,
                        width: _selectedOption == opt ? 1.0 : 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedOption == opt
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          size: 18,
                          color: T.text,
                        ),
                        const SizedBox(width: T.s2),
                        Expanded(
                          child: Text(opt,
                              style: T.body.copyWith(
                                fontWeight: _selectedOption == opt
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: T.s3),

          // Feedback message
          if (_isCorrect != null) ...[
            Container(
              padding: const EdgeInsets.all(T.s3),
              decoration: BoxDecoration(
                color: _isCorrect!
                    ? T.mint.withValues(alpha: 0.6)
                    : T.rose.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: T.hairline, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isCorrect!
                        ? CupertinoIcons.checkmark_alt_circle_fill
                        : CupertinoIcons.exclamationmark_circle_fill,
                    size: 20,
                    color: T.text,
                  ),
                  const SizedBox(width: T.s2),
                  Expanded(
                    child: Text(_feedbackMessage,
                        style: T.secondary.copyWith(
                            color: T.text, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: T.s3),
          ],

          // Action Button
          if (_isCorrect != true)
            PillButton(
              'Verificar',
              icon: CupertinoIcons.checkmark,
              color: T.lavender,
              onTap: (ex.type == ExerciseType.sentenceBuilder &&
                          _builderSelected.isNotEmpty) ||
                      (ex.type != ExerciseType.sentenceBuilder &&
                          _selectedOption != null)
                  ? _checkExercise
                  : null,
            )
          else
            PillButton(
              _activeExercise + 1 < widget.topic.exercises.length
                  ? 'Próximo Exercício'
                  : 'Finalizar Tópico',
              icon: CupertinoIcons.arrow_right,
              color: T.mint,
              onTap: _nextExercise,
            ),
        ],
      ),
    );
  }
}
