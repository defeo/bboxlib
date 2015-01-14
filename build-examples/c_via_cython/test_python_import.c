#include <Python.h>

int main () {
    // PyObject est un wrapper Python autour des objets qu'on
    // va échanger enter le C et Python.
    PyObject *retour, *module, *fonction;
    int resultat;

    // Initialisation de l'interpréteur. A cause du GIL, on ne peut
    // avoir qu'une instance de celui-ci à la fois.
    Py_Initialize();   

    // Import du script. 
    PySys_SetPath("."); // Le dossier en cours n'est pas dans le PYTHON PATH
    module = PyImport_ImportModule("aes");
    if(module == NULL){ printf("Module non charge");}

    // Récupération de la fonction
    fonction = PyObject_GetAttrString(module, "main");
    if(fonction == NULL){ printf("Fonction non charge");}

    // Création d'un PyObject de type string. Py_BuildValue peut créer
    // tous les types de base Python. Voir :
    // https://docs.python.org/2/c-api/arg.html#c.Py_BuildValue
    //arguments = Py_BuildValue("(s)", "Leroy Jenkins"); 

    // Appel de la fonction.
    retour = PyEval_CallObject(fonction, NULL);
    if(retour == NULL){ printf("Retour non charge");}
    
    // Conversion du PyObject obtenu en string C
    PyArg_Parse(retour, "i", &resultat);

    printf("Resultat: %d\n", resultat);

    // On ferme cet interpréteur.
    Py_Finalize(); 
    return 1;
}
