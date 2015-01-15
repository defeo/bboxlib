# Description du programme fourni

Nous allons livrer un programme sous forme de code source. Il s'agit
d'un générateur de code, prenant en entrée une description abstraite
d'une bijection sur 128 bits, et donnant en sortie du code C ou Java
réalisant la bijection.

Nous avons développé un Domain Specific Language (DSL) pour la
description abstraite des bijections. Dans la suite nous appelons
simplement DSL ce langage. DSL permet de décrire une bijection
paramétrée par des valeurs, par exemple une clef
cryptographique. Lorsque une bijection B est paramétrée par des
variables a, b, ... nous écrivons B(a=x, b=y, ...) pour indiquer la
restriction de la bijection aux valeurs numériques x, y, ... L'exemple
type d'une telle bijection est un tour de AES :

    AES(k=x)

qui est paramétré par une clef de tour `k` de 128 bits.

Le programme va fournir l'API suivante, sous forme de commandes shell,
ou autre forme à définir (bibliothèque dynamique, API web (HTTP),
etc.)

- GENERATE(codeDSL, lang)

	* codeDSL: chaîne de caractères décrivant une bijection en langage
		DSL
	* lang: 'C' ou 'Java', pour déterminer le langage de sortie
	
	Génère le code C ou Java réalisant la bijection décrite dans
    codeDSL. Le code est encapsulé dans une fonction qui prend en
    paramètres 128 bits, et les paramètres de la bijection, et qui
    donne en sortie la sortie de la bijection.

- GENERATE_SLICE(codeDSL, a=x, b=y, ..., lang)

	* codeDSL: chaîne de caractères décrivant une bijection en langage
		DSL
	* a=x, b=y, ...: valeurs numériques d'initialisation des
		paramètres. Les valeurs sont automatiquement tronquées à la
		taille du paramètre.
	* lang: 'C' ou 'Java', pour déterminer le langage de sortie
	
	Comme GENERATE, mais les paramètres a, b, ... sont instanciés aux
    valeurs x, y, ... dans le code généré. Le code est encapsulé dans
    une fonction qui prend en entrée UNIQUEMENT l'entrée de la
    bijection et qui donne en sortie sa sortie.

- GENERATE_CAT([ codeDSL1, codeDSL2, ... ], lang)

	* [ codeDSL1, ...]: liste de chaînes de caractères décrivant des
		bijections en langage DSL
	* lang: 'C' ou 'Java', pour déterminer le langage de sortie

	Comme GENERATE, mais les bijections codeDSL1, codeDSL2, ... sont
    composées (concaténées) dans l'ordre dans lequel elles
    apparaissent dans la liste. La totalité du code est encapsulée
    dans une fonction qui prend en entrée 128 bits, et les paramètres
    de chaque bijection, et qui donne en sortie la sortie de la
    composition.

- GENERATE_SLICE_CAT([ (codeDSL1, a=x, b=y, ...), (codeDSL2, c=z, ...) ], lang)

	Comme GENERATE_SLICE, mais chacune des bijection est instanciée
    avec les valeurs numériques x, y, ..., et la la liste des
    bijections résultantes est composée. Le code est encapsulé dans
    une fonction qui prend en entrée 128 bits et qui donne en sortie
    128 bits.

Un exemple de code Java pour un tour de AES généré par GENERATE se
trouve à l'adresse
<https://github.com/sebsheep/bboxlib/blob/master/build-examples/java/Testaes.java>


# Question pour le client

1. Concernant la sortie C, y a-t-il des restrictions sur le langage de
   sortie ? Quel standard C est autorise ? Peut-on supposer que le
   code est compilé avec gcc sur une plateforme x86_64 ? En
   particulier, peut-on utiliser le type int128 ?

2. Même question concernant la sortie Java ? Quelle partie de la
   bibliothèque standard est autorisée ? En particulier, peut-on
   utiliser BigInteger ?

3. Est-on autorisés à faire appel à des bibliothèques externes
   (ex. gmp) ?
