###########################################################################################################
#
# Dieses Skript beinhaltet den Workflow "SDM" zur Vorhersage der Habitateignung von Arten
# mit Vorkommen in Deutschland. Der Workflow besteht aus sieben Arbeitsschritte, die nacheinander ausge-
# fuehrt werden. Eine Beschreibung der einzelnen Arbeitsschritte befindet sich im Abschlussbericht des 
# Projektvorhabens "Erweiterung des Modells CASPIAN zur Prognose der Einfuhr und Ausbreitung von invasiven 
# Arten durch verschiedene Verkehrstraeger (CASPIAN II)". 
#
# Author: Hanno Seebens, Senckenberg Gesellschaft fuer Naturforschung, 17.07.23
##########################################################################################################

## Bereinigen der Arbeitsumgebung
graphics.off()
rm(list=ls())


##########################################################################################################
## Konfiguration der Habitatmodellierung #################################################################
##########################################################################################################


##########################################################################################################
## Artenliste ############################################################################################

# Name des Datensatzes, welches die Artenliste enthaelt. Dies muss eine .xlsx Datei sein mit den Spalten "Taxon"
# und "Eintraege_GBIF_DE" sein. Eine entsprechende Datei mit dem Workflow "ListeNeobiota" generiert.

Name_Artenliste <- "ListeGebietsfremderArten_gesamt_standardisiert_AbutilonTheophrasti.xlsx"

# Limits der Datenmenge fuer eine Habitatmodellierung (nur auf GBIF bezogen; weitere Datenpunkte 
# aus anderen Datenbanken zusaetzlich bezogen werden.)
Min_Anzahl_GBIF_DE <- 50 # sollte 50 nicht unterschreiten
Max_Anzahl_GBIF_DE <- 20000 # sollte 20000 nicht ueberschreiten


##########################################################################################################
## Parameter zur Modellierung ############################################################################

## Name des jeweiligen Modelllaufs (frei vom Nutzer zu waehlen)
identifier <- "BeispielArt_AbutilonTheophrasti" # eine eindeutige Kennzeichnung des Modelllaufs (z.B. Datum)

## Variablen zur Vorhersage der Habitate ##########################################

## Klimatische Variablen (Gesamtliste und uebersetzung: https://www.worldclim.com/bioclim).
# Die Codes des Variablen findet man entweder auf der Homepage oder im Abschlussbericht des Projektvorhabens.
Klima_var <- c("bio1","bio12","bio4") 

## Variablen zu Landbedeckung
# LC2+LC3: urbane Regionen; LC12: Acker; LC18: Weideland/Grasland; LC23+LC24+LC25: Waelder; LC40+LC41: Binnengewaesser
# Die Bedeckung mit den Variablen LC2, LC3, LC12, LC18, LC23, LC24, LC25 entsprechen 94% der Flaeche von Deutschland.
# Die Codes der Variablen findet man im Abschlussbericht des Projekvorhabens.
Landbedeck_var <- c("LC2","LC3", "LC12","LC18","LC23","LC24","LC25","LC40","LC41")

## Geographischer Fokus ############################################################
# Geographischer Ausschnitt zum Fitten des Modells (Ausschnitt_ModellFit) und zur Vorhersage/Extrapolation der Ergebnisse (Ausschnitt_Extrapolation)
# Angaben beschreiben die Ausdehnung eines Rechtecks (long/lat fuer linke, untere und rechte, obere Ecke hintereinander)
Ausschnitt_ModellFit <- c(-30,25,40,78) # Grenzen von Europa (Modell wird fuer alle Vorkommen in Europa angefittet)
Ausschnitt_Extrapolation <- c(3,47,17,55) # Grenzen von Deutschland zur Extrapolation und Darstellung der Ergebnisse


## Anzahl der Laeufe zur Generierung von Absenzdaten (pseudo absences) ##############
# Gesamtzahl der Modelllaeufe = n_AbsenzLaufe * n_Modelllaeufe
n_AbsenzDaten <- 5

## Anzahl der Modellaeufe zur Evaluierung der Modellergebnisse (Validierung) ########
# Gesamtzahl der Modelllaeufe = n_AbsenzLaufe * n_Modelllaeufe
n_Modelllaeufe <- 5

##########################################################################################################
## Ende: Konfiguration der Habitatmodellierung ###########################################################
##########################################################################################################



###########################################################################################################
##### Beginn: Habitatmodellierung #########################################################################
###########################################################################################################
## (In den folgenden Zeilen muessen keine Anpassungen mehr vorgenommen werden. Die obigen 
## Konfigurationen werden uebernommen.)
###########################################################################################################

## Schritt 0: Vorbereitung der Habitatmodellierung ########################################################


###########################################################################################################
## Lade Funktionen ########################################################################################

source(file.path("LadeSkripte.R")) 

###########################################################################################################
## Lade und installiere (sofern noch nicht geschehen) notwendige R Pakete #################################

LadePakete()

###########################################################################################################
## Ueberpruefe und erstelle Verzeichnisstruktur (sofern noch nicht geschehen) #############################

ueberpruefe_Verzeichnisse()

###########################################################################################################
## Ueberpruefe Datensaetze (Artenliste und Daten der Vorhersagevariablen) #################################

ueberpruefe_Datensaetze(Klima_var=Klima_var,
                        Landbedeck_var=Landbedeck_var,
                        Name_Artenliste=Name_Artenliste)

###########################################################################################################
## Lade Artenliste ########################################################################################

Artenliste <- importiereArtenliste(Name_Artenliste=Name_Artenliste,
                                   Min_Anzahl_GBIF_DE=Min_Anzahl_GBIF_DE,
                                   Max_Anzahl_GBIF_DE=Max_Anzahl_GBIF_DE)

## check identifier separator
if (strtrim(identifier,1)!="_"){
  identifier <- paste0("_",identifier)
}

###########################################################################################################
## Generiere Tabelle zum Stand der Modellierung fuer jede Art #############################################

erstelleStatusFile(Name_Artenliste=Name_Artenliste,
                   identifier=identifier,
                   ueberschreiben=FALSE,
                   Min_Anzahl_GBIF_DE=Min_Anzahl_GBIF_DE,
                   Max_Anzahl_GBIF_DE=Max_Anzahl_GBIF_DE)

##########################################################################################################
## Schleife ueber alle Arten zur Berechnung der Habitateignung
for (i in 1:length(Artenliste)){ #
  
  ## Auswahl einer Art ###################################################################################
  TaxonName <- Artenliste[i]  ## Taxonname
  # TaxonName <- "Teredo navalis"
  # TaxonName <- "Amaranthus blitum emarginatus"
  
  cat(paste0("\n\n************* Bearbeitung von ",TaxonName," ************* \n") ) # notification for the user
  
  
  ##########################################################################################################
  ## Datenermittlung #######################################################################################
  ## Aufbereitung aller notwendiger Daten (Vorkommen der Art, Umweltdaten und Pseudo-Absenz Daten)
  
  ## Schritt 1: Ermittlung und Aufbereitung der Vorkommensdaten #############################################
  
  Vorkommen <- ermittleVorkommen(TaxonName=TaxonName,
                                 Datenbank=c("OBIS","GBIF","iNat"),
                                 Ausschnitt=Ausschnitt_ModellFit,
                                 identifier=identifier,
                                 max_limit=20000)
  ## Alternativ: Lade existierende Datei von Festplatte:
  # Vorkommen <- fread(file.path("SDM","Data","Input",paste0("Vorkommen_",TaxonName,identifier,".csv"))) # stores the final occurrence file on the users computer
  
  if (!is.data.frame(Vorkommen)){
    next # falls keine Vorkommensdaten bezogen werden konnten, ueberspringe diese Art
  } 
  
  ## Schritt 2: Kombiniere Vorkommensdaten und Umweltdaten ################################################
  
  VorkommenUmwelt <- ermittleUmweltdaten(TaxonName,
                                         Vorkommen=Vorkommen,
                                         identifier=identifier,
                                         Klima_var,
                                         Landbedeck_var,
                                         Ausschnitt=Ausschnitt_ModellFit,
                                         plot_predictors=FALSE)
  
  ## Alternativ: Lade existierende Datei von Festplatte:
  # VorkommenUmwelt <- fread(file.path("SDM","Data","Input",paste0("VorkommenUmweltdaten_",TaxonName,"_",identifier,".csv"))) # stores the final occurrence file on the users computer
  
  
  ## Schritt 3: Generiere Pseudo-Absence Daten ##############################################################
  
  VorkommenUmweltPA <- generiereAbsenzDaten(TaxonName=TaxonName,
                                            VorkommenUmwelt=VorkommenUmwelt,
                                            n_AbsenzDaten=n_AbsenzDaten,
                                            speichern=TRUE,
                                            identifier=identifier)
  
  ## Alternativ: Lade existierende Datei von Festplatte:
  # load(file=file.path("SDM","Data","Input", paste0("PAlist_",TaxonName,"_",identifier,".RData"))) # load file 'PAlist'
  # VorkommenUmweltPA <- PAlist
  
  
  ###########################################################################################################
  ### Eigentliche Habitatmodellierung #######################################################################
  
  ## Schritt 4: kalibriere (fit) und validiere Modell #######################################################
  
  Modelllaeufe <- fit_SDMs(TaxonName=TaxonName,
                           VorkommenUmweltPA=VorkommenUmweltPA,
                           n_Modelllaeufe=n_Modelllaeufe,
                           identifier=identifier)
  
  ## Alternativ: Lade existierende Datei von Festplatte:
  # load(file=file.path("SDM","Data","Output", paste0("ModelFit_",TaxonName,"_",identifier,".RData"))) # lade Datei 'modelruns'
  # Modelllaeufe <- modelruns
  
  
  ##########################################################################################################
  ### Bearbeitung der Ergebnisse ###########################################################################
  
  ## Schritt 5: generiere Vorhersage #######################################################################
  
  HabitatEignung <- Vorhersage_alleLaeufe(TaxonName=TaxonName,
                                          Modelllaeufe=Modelllaeufe,
                                          Ausschnitt=Ausschnitt_Extrapolation,
                                          speichern=TRUE,
                                          identifier=identifier)
  
  ## Alternativ: Lade existierende Datei von Festplatte:
  HabitatEignung <- fread(file=file.path("SDM","Data","Output", paste0("HabitatEignung_",TaxonName,identifier,".gz")))
  
  ## Schritt 6: Erstelle Karte der Habitateignung ########################################################
  
  rasterHabitatEignung <- erstelleKarteHabitatEignung(HabitatEignung=HabitatEignung,
                                                      Vorkommen=Vorkommen,
                                                      identifier=identifier) #
  
  cat(paste0("\n************* Bearbeitung von ",TaxonName," beendet ************* \n") ) # notification for the user
  
} # Ende der Habitatmodellierung fuer einzelne Arten

