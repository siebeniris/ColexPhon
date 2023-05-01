# Obtain and format raw data

#files that must be obtained manually from CELEX CD - we cannot provide these due to copyright restrictions
file.copy(overwrite=T,"C:/Users/JSAde/Documents/dpw.cd",".")
file.copy(overwrite=T,"C:/Users/JSAde/Documents/gpw.cd",".")

write("#!/usr/bin/perl

BEGIN {
  use File::Basename;
  # Add current path to perl library search path
  use lib dirname($0);
}

use strict;
#use Spreadsheet::ParseExcel;
#use Spreadsheet::ParseXLSX;
use File::Spec::Functions;
use Getopt::Std;

##
# Try to load the modules we need
##
require 'module_tools.pl';
my(
   $HAS_Spreadsheet_ParseExcel,
   $HAS_Compress_Raw_Zlib,
   $HAS_Spreadsheet_ParseXLSX
  ) = check_modules_and_notify();

# declare some varibles local
my($row, $col, $sheet, $cell, $usage,
   $targetfile,$basename, $sheetnumber,
   $filename, $volume, $directories, $whoami,
   $sep, $sepName, $sepLabel, $sepExt,
   $skipBlankLines, %switches,
   $parser, $oBook, $formatter,
   $using_1904_date
);

##
## Figure out whether I'm called as xls2csv.pl or xls2tab.pl
##
($volume,$directories,$whoami) = File::Spec->splitpath( $0 );

if($whoami eq \"xls2csv.pl\")
  {
    $sep=\",\";
    $sepName=\"comma\";
    $sepLabel=\"CSV\";
    $sepExt=\"csv\";

  }
elsif ($whoami eq \"xls2tsv.pl\")
  {
    $sep=\"\\t\";
    $sepName=\"tab\";
    $sepLabel=\"TSV\";
    $sepExt=\"tsv\";
  }
elsif ($whoami eq \"xls2tab.pl\")
  {
    $sep=\"\\t\";
    $sepName=\"tab\";
    $sepLabel=\"TAB\";
    $sepExt=\"tab\";
  }
else
  {
    die(\"This script is named '$whoami', but must be named 'xls2csv.pl', 'xls2tsv', or 'xls2tab.pl' to function properly.\\r\n\");
  }


##
## Usage information
##
$usage = <<EOF;

$whoami [-s] <excel file> [<output file>] [<worksheet number>] [<password>]

Translate the Microsoft Excel spreadsheet file contained in <excel
file> into $sepName separated value format ($sepLabel) and store in
<output file>, skipping blank lines unless \"-s\" is present.

If <output file> is not specified, the output file will have the same
name as the input file with '.xls', or 'xlsx' removed and '.$sepExt'
appended.

If no worksheet number is given, each worksheet will be written to
a separate file with the name '<output file>_<worksheet name>.$sepExt'.

EOF

##
## parse arguments
##

# Handle switches (currently, just -s)
getopts('s', \\%switches);
$skipBlankLines=!$switches{s};

# Now the rest of the arguments

if( !defined($ARGV[0]) )
  {
    print $usage;
    exit 1;
  }

if( defined($ARGV[1]) )
   {
     $basename = $targetfile = $ARGV[1];
     $basename =~ s/\\.$sepExt$//i;
   }
else
   {
     ($volume,$directories,$basename) = File::Spec->splitpath( $ARGV[0] );
     $basename =~ s/\\.xlsx*//i;
   }

my $targetsheetname;
my $sheetnumber;
my $password;

if(defined($ARGV[2]) )
  {
    if ( $ARGV[2] =~ m|^\\d+$| )
      {
	$sheetnumber = $ARGV[2];
	die \"Sheetnumber must be an integer larger than 0.\\r\n\" if $sheetnumber < 1;
      }
    else
      {
	$targetsheetname = $ARGV[2];
      }
  }

if(defined($ARGV[3]) )
  {
    $password = $ARGV[3];
  }
##
## open spreadsheet
##

my $oExcel;
my $oBook;

$oExcel    = new Spreadsheet::ParseExcel;
$formatter = Spreadsheet::ParseExcel::FmtDefault->new();

open(FH, \"<$ARGV[0]\") or die \"Unable to open file '$ARGV[0]'.\\r\n\";
close(FH);

print \"\\r\n\";
print \"Loading '$ARGV[0]'...\\r\n\";
## First try as a Excel 2007+ 'xml' file
eval
  {
    local $SIG{__WARN__} = sub {};
    $parser = Spreadsheet::ParseXLSX -> new();
    $oBook = $parser->parse ($ARGV[0]);
  };
## Then Excel 97-2004 Format
if ( !defined $oBook )
  {
    if( !defined $password )
      {
        $parser = Spreadsheet::ParseExcel -> new();
      }
    else
      {
        $parser = Spreadsheet::ParseExcel -> new( Password => $password );
      }
    $oBook = $parser->parse($ARGV[0]) or \\
      die \"Error parsing file '$ARGV[0]'.\\r\n\";
  }
print \"Done.\\r\n\";

## Does this file use 1904-01-01 as the reference date instead of
## 1900-01-01?
$using_1904_date = ( $oBook->using_1904_date() == 1 ) || # ParseExcel
                   ( $oBook->{Flag1904}        == 1 );   # ParseXLSX


## Show the user some summary information before we start extracting
## date
print \"\\r\n\";
print \"Orignal Filename: \", $ARGV[0], \"\\r\n\";
print \"Number of Sheets: \", $oBook->{SheetCount} , \"\\r\n\";
if($using_1904_date)
  {
      print \"Date reference  : 1904-01-01\\r\n\";
  }
else
  {
      print \"Date reference  : 1900-01-01\\r\n\";
  }

print \"\\r\n\";

## Get list all worksheets in the file
my @sheetlist =  (@{$oBook->{Worksheet}});
my $sheet;

## If we want a specific sheet drop everything else
if ( defined($sheetnumber) )
  {
    $sheet = $oBook->Worksheet($sheetnumber-1) or die \"No sheet number $sheetnumber.\\r\n\";
    @sheetlist = ( $sheet  );

  }
elsif ( defined($targetsheetname) )
  {
    $sheet = $oBook->Worksheet($targetsheetname) or die \"No sheet named '$targetsheetname'.\\r\n\";
    @sheetlist = ( $sheet  );
  }


##
## iterate across each worksheet, writing out a separat csv file
##

my $i=0;
my $sheetname;
my $found=0;
foreach my $sheet (@sheetlist)
{
  $i++;


  $sheetname = $sheet->{Name};

  if( defined($sheetnumber) || defined($targetsheetname) || $oBook->{SheetCount}==1 )
    {
      if( defined($targetfile) )
	{
	  $filename = $targetfile;
	}
      else
	{
	  $filename = \"${basename}.$sepExt\";
	}
    }
  else
    {
      $filename = \"${basename}_${sheetname}.$sepExt\";
    }

  if( defined($sheetnumber) )
    {
      print \"Writing sheet number $sheetnumber ('$sheetname') to file '$filename'\\r\n\";
    }
  elsif ( defined($targetsheetname) )
    {
      print \"Writing sheet '$sheetname' to file '$filename'\\r\n\";
    }
  else
    {
      print \"Writing sheet number $i ('$sheetname') to file '$filename'\\r\n\";
    }

  open(OutFile,\">$filename\");

  my $cumulativeBlankLines=0;

  my $minrow = $sheet->{MinRow};
  my $maxrow = $sheet->{MaxRow};
  my $mincol = $sheet->{MinCol};
  my $maxcol = $sheet->{MaxCol};

  print \"Minrow=$minrow Maxrow=$maxrow Mincol=$mincol Maxcol=$maxcol\\r\n\";

  for(my $row =  $minrow; $row <= $maxrow; $row++)
    {
       my $outputLine = \"\";

       for(my $col = $mincol; $col <= $maxcol; $col++)
         {
           my $cell   = $sheet->{Cells}[$row][$col];
	   my $format = $formatter->FmtString($cell, $oBook);
	   if( defined($cell) )
	      {
		  if ($cell->type() eq \"Date\") # && $using_1904_date )
		    {
			my $is_date = ( $format =~ m/y/ &&
					$format =~ m/m/ &&
					$format =~ m/d/ );

			my $is_time = ( $format =~ m/h[:\\]]*m/ ||
					$format =~ m/m[:\\]]*s/ );


			if($is_date && $is_time)
			  {
			      $format = \"yyyy-mm-dd hh:mm:ss.00\";
			  }
			elsif ($is_date)
			  {
			      $format = \"yyyy-mm-dd\";
			  }
			elsif ($is_time)
			  {
			      $format = \"hh:mm:ss.00\"
			  }

			$_ = ExcelFmt($format,
				      $cell->unformatted(),
				      $using_1904_date);
		    }
		  else
		    {
		      $_=$cell->value();
		    }

		# convert '#NUM!' strings to missing (empty) values
		s/#NUM!//;

		# convert \"#DIV/0!\" strings to missing (emtpy) values
                s|#DIV/0!||;

		# escape double-quote characters in the data since
		# they are used as field delimiters
		s/\\\"/\\\\\\\"/g;
	      }
	   else
	     {
	       $_ = '';
	     }

	   $outputLine .= \"\\\"\" . $_ . \"\\\"\" if(length($_)>0);

	   # separate cells with specified separator
	   $outputLine .= $sep if( $col != $maxcol) ;

         }

       # skip blank/empty lines
       if( $skipBlankLines && ($outputLine =~ /^[$sep ]*$/) )
       	 {
       	   $cumulativeBlankLines++
       	 }
       else
       	 {
	   print OutFile \"$outputLine\\r\n\"
	 }
     }

  close OutFile;

  print \"  (Ignored $cumulativeBlankLines blank lines.)\\r\n\"
      if $skipBlankLines;
  print \"\\r\n\";
}
",file="xls2csv.pl")

require(gdata)
require("openxlsx")
require("httr")
require("pdftools")
require("lattice")

writeUtf8 <- function(x, con, bom=F, open="wb", closeAtEnd=is.character(con)) {
  closeAtEnd<-closeAtEnd
  BOM <- charToRaw('\xEF\xBB\xBF')
  if(is.character(con)) con <- file(con, open)
  if(bom) writeBin(BOM, con, endian="little")
  writeBin(charToRaw(x), con, endian="little")
  if(closeAtEnd) close(con)
}

tableToText<-function(x,sep="\t") {
  paste(sep="\r\n",
    paste(c("",colnames(x)),collapse=sep),
    paste(apply(data.frame(Predictor=rownames(x),x),1,paste,collapse=sep),collapse="\r\n"),
    ""
  )
}
tableToCsv<-function(x) {
  tableToText(x,sep=",")
}

findPerl <- function()
{
  errorMsg <- "perl executable not found. Use perl= argument to specify the correct path."
  perl = Sys.which("perl")
  if (perl=="" || perl=="perl")
    stop(errorMsg)

  if (.Platform$OS == "windows") {
    if (length(grep("rtools", tolower(perl))) > 0) {
      perl.ftype <- shell("ftype perl", intern = TRUE)
      if (length(grep("^perl=", perl.ftype)) > 0) {
        perl <- sub('^perl="([^"]*)".*', "\\1", perl.ftype)
      }
    }
  }

  perl
}

xls2csv_pwd<-function(xls,csv,sheet=1,password="")
{
  perl<-findPerl()
  cmd <- paste(shQuote(perl),
               shQuote(paste(sep="","-I",find.package("gdata"),"/perl")),
               shQuote(file.path(getwd(),"xls2csv.pl")),
               shQuote(xls),
               shQuote(csv),
               shQuote(sheet),
               ifelse(password=="","",shQuote(password))
  )
  str(cmd)
  print(cmd)
  
  system(cmd)
}

cent<-function(x)scale(na.exclude(x),scale=F)
create_contrast_coefs<-function(main,counts){
  ret<-NULL; 
  controltab<-summary(lm(cent(Valence)~cent(LgWF)+cent(LgCD)+cent(Length)
                     +cent(Arousal)+apply(counts,2,cent),main))[[4]]
  controltab<-controltab[!grepl("apply",rownames(controltab)),][-1,]
  for(i in 1:dim(counts)[2]) { 
    temp<-counts[,-i]+outer(counts[,i],apply(counts[,-i],2,sum)/sum(counts[,-i]),"*"); 
    temp<-cbind(temp,counts[,i]); 
    temptab<-summary(lm(cent(Valence)~cent(LgWF)+cent(LgCD)+cent(Length)
                     +cent(Arousal)+cent(apply(counts,1,sum))+temp,main))[[4]]; 
    ttab<-temptab[dim(temptab)[1],,drop=F]; 
    rownames(ttab)<-colnames(counts)[i]; 
    ret<-rbind(ret,ttab);
  }; 
  list(controls=controltab,phonemes=ret)
}


# ENGLISH

download.file("https://static-content.springer.com/esm/art%3A10.3758%2Fs13428-012-0314-x/MediaObjects/13428_2012_314_MOESM1_ESM.zip",destfile="Warriner.zip") # E aff
unzip("Warriner.zip")
download.file("http://svn.code.sf.net/p/cmusphinx/code/trunk/cmudict/cmudict.0.7a",destfile="CMU.txt") # E pron
Ad<-GET("http://supp.apa.org/psycarticles/supplemental/a0031829/ArousalValence.xlsx",destfile="Adelman.xlsx") 
writeBin(content(Ad,"raw"),"Adelman.xlsx")
rm("Ad")

read.csv("BRM-emot-submit.csv")->Eaff
Eaff$Word<-as.character(Eaff$Word)
Eaff[Eaff$Word=="TRUE",]$Word<-"true"
Eaff[Eaff$Word=="FALSE",]$Word<-"false"
read.xlsx("Adelman.xlsx",1,startRow=2)->E2aff
colnames(E2aff)<-c("Word","DK","Arousal","ArousalSD","Valence","ValenceSD")
read.table(stringsAsFactors=F,file="CMU.txt",quote=NULL,sep=" ",comment.char=";",fill=T,col.names=c("Word","x",paste("P",1:20,sep="")))[,-2]->Epron
Epron[,1]<-tolower(Epron[,1])
Epron<-subset(Epron,!is.na(Word))
create_cmu_compound <-
function(x,y,z=NULL) {
  w<-paste(x,y,z,sep="")
  xx<-Epron[Epron$Word==x,-1]
  yy<-Epron[Epron$Word==y,-1]
  zz<-character(0)
  if(!is.null(z))
  {
    zz<-Epron[Epron$Word==z,-1]
  }
  if(y=="ful")  yy<-c("F","AH","L")
  if(y=="ness") yy<-c("N","AH","S")
  if(y=="less") yy<-c("L","AH","S")
  if(y=="man")  yy<-c("M","AH","N")
  if(y=="y")  yy<-c("IY")
  xx<-xx[xx!=""]
  yy<-yy[yy!=""]
  p<-c(xx,yy,zz,rep("",20))[1:20]
  ret<-cbind(data.frame(Word=w),t(as.matrix(p)))
  names(ret)<-c("Word",paste("P",1:20,sep=""))
  ret
}
AIDS<-Epron[Epron$Word=="aids",]
AIDS$Word<-"AIDS"
nuptials<-Epron[Epron$Word=="nuptial",]
nuptials$Word<-"nuptials"
squaw<-Epron[Epron$Word=="squawk",]
squaw$Word<-"squaw"
squaw$P5<-""
leprechaun<-Epron[Epron$Word=="leper",]
leprechaun$Word<-"leprechaun"
leprechaun$P6<-"K"
leprechaun$P7<-"AO"
leprechaun$P8<-"N"
gaga<-Epron[Epron$Word=="saga",]
gaga$Word<-"gaga"
gaga$P1<-"G"
spectral<-Epron[Epron$Word=="spectrum",]
spectral$Word<-"spectral"
spectral$P8<-"L"
spastic<-Epron[Epron$Word=="elastic",]
spastic$Word<-"spastic"
spastic$P1<-"S"
spastic$P2<-"P"
amour<-Epron[Epron$Word=="ummel",]
amour$Word<-"amour"
amour$P3<-"UW"
amour$P4<-"R"
smooch<-Epron[Epron$Word=="smooth",]
smooch$Word<-"smooch"
smooch$P4<-"CH"
congrats<-Epron[Epron$Word=="congratulations",]
congrats$Word<-"congrats"
congrats$P7<-"T"
congrats$P8<-"S"
congrats[,10:15]<-""
scram<-Epron[Epron$Word=="scramble",]
scram$Word<-"scram"
scram$P7<-""
scram$P8<-""
exorcism<-Epron[Epron$Word=="exorcist",]
exorcism$Word<-"exorcism"
exorcism$P6<-"IH"
exorcism$P7<-"Z"
exorcism$P8<-"AH"
exorcism$P9<-"M"
exorcism[,11:15]<-""
succubus<-Epron[Epron$Word=="succulent",]
succubus$Word<-"succubus"
succubus$P6<-"B"
succubus$P7<-"AH"
succubus$P8<-"S"
succubus$P9<-""
velour<-Epron[Epron$Word=="vela",]
velour$Word<-"velour"
velour$P4<-"UW"
velour$P5<-"R"
wench<-Epron[Epron$Word=="wrench",]
wench$Word<-"wench"
wench$P1<-"W"
Epron<-rbind(Epron,
  AIDS,
  amour,
  congrats,
  exorcism,
  gaga,
  leprechaun,
  nuptials,
  scram,
  smooch,
  spastic,
  spectral,
  squaw,
  succubus,
  velour,
  wench,
  create_cmu_compound("apple","jack"),
  create_cmu_compound("bar","keep"),
  create_cmu_compound("bar","maid"),
  create_cmu_compound("belly","ful"),
  create_cmu_compound("black","mailer"),
  create_cmu_compound("blood","shot"),
  create_cmu_compound("bon","bon"),
  create_cmu_compound("bonds","man"),
  create_cmu_compound("bone","head"),
  create_cmu_compound("bull","headed"),
  create_cmu_compound("bumble","bee"),
  create_cmu_compound("bung","hole"),
  create_cmu_compound("bunk","house"),
  create_cmu_compound("busy","body"),
  create_cmu_compound("catch","phrase"),
  create_cmu_compound("chamber","maid"),
  create_cmu_compound("chatter","box"),
  create_cmu_compound("chip","munk"),
  create_cmu_compound("clothes","line"),
  create_cmu_compound("cod","fish"),
  create_cmu_compound("coffee","pot"),
  create_cmu_compound("corn","flakes"),
  create_cmu_compound("cow","hand"),
  create_cmu_compound("dill","dough"),
  create_cmu_compound("dragon","fly"),
  create_cmu_compound("drain","pipe"),
  create_cmu_compound("dream","boat"),
  create_cmu_compound("duck","y"),
  create_cmu_compound("dust","pan"),
  create_cmu_compound("ear","ful"),
  create_cmu_compound("faith","less"),
  create_cmu_compound("fat","head"),
  create_cmu_compound("fire","light"),
  create_cmu_compound("flame","thrower"),
  create_cmu_compound("flat","foot"),
  create_cmu_compound("flea","bag"),
  create_cmu_compound("forgetful","ness"),
  create_cmu_compound("gang","land"),
  create_cmu_compound("gang","way"),
  create_cmu_compound("god","damned"),
  create_cmu_compound("god","forsaken"),
  create_cmu_compound("god","like"),
  create_cmu_compound("god","son"),
  create_cmu_compound("guard","house"),
  create_cmu_compound("gun","play"),
  create_cmu_compound("hair","brush"),
  create_cmu_compound("hair","pin"),
  create_cmu_compound("high","ball"),
  create_cmu_compound("horse","shit"),
  create_cmu_compound("hot","head"),
  create_cmu_compound("house","boy"),
  create_cmu_compound("jail","bird"),
  create_cmu_compound("jail","break"),
  create_cmu_compound("ca","baab"),
  create_cmu_compound("lady","ship"),
  create_cmu_compound("long","boat"),
  create_cmu_compound("lord","ship"),
  create_cmu_compound("loud","mouth"),
  create_cmu_compound("love","sick"),
  create_cmu_compound("night","cap"),
  create_cmu_compound("night","gown"),
  create_cmu_compound("nurse","maid"),
  create_cmu_compound("nut","case"),
  create_cmu_compound("nut","house"),
  create_cmu_compound("out","rank"),
  create_cmu_compound("pass","key"),
  create_cmu_compound("peek","a","boo"),
  create_cmu_compound("peep","hole"),
  create_cmu_compound("penman","ship"),
  create_cmu_compound("penta","gram"),
  create_cmu_compound("pig","headed"),
  create_cmu_compound("pill","box"),
  create_cmu_compound("pillow","case"),
  create_cmu_compound("pin","head"),
  create_cmu_compound("pin","up"),
  create_cmu_compound("pip","squeak"),
  create_cmu_compound("play","time"),
  create_cmu_compound("porter","house"),
  create_cmu_compound("port","hole"),
  create_cmu_compound("pot","head"),
  create_cmu_compound("rick","shaw"),
  create_cmu_compound("sales","girl"),
  create_cmu_compound("school","girl"),
  create_cmu_compound("sheep","dog"),
  create_cmu_compound("shuffle","board"),
  create_cmu_compound("sick","bay"),
  create_cmu_compound("side","burns"),
  create_cmu_compound("side","car"),
  create_cmu_compound("simple","ton"),
  create_cmu_compound("silence","er"),
  create_cmu_compound("sir","loin"),
  create_cmu_compound("six","pence"),
  create_cmu_compound("sleepy","head"),
  create_cmu_compound("snot","y"),
  create_cmu_compound("sound","proof"),
  create_cmu_compound("sour","puss"),
  create_cmu_compound("south","paw"),
  create_cmu_compound("spare","ribs"),
  create_cmu_compound("speak","easy"),
  create_cmu_compound("spit","fire"),
  create_cmu_compound("spit","toon"),
  create_cmu_compound("state","room"),
  create_cmu_compound("stock","ade"),
  create_cmu_compound("stomach","ache"),
  create_cmu_compound("stow","away"),
  create_cmu_compound("strap","less"),
  create_cmu_compound("street","light"),
  create_cmu_compound("sub","space"),
  create_cmu_compound("summer","house"),
  create_cmu_compound("super","position"),
  create_cmu_compound("swords","man"),
  create_cmu_compound("tail","light"),
  create_cmu_compound("tape","worm"),
  create_cmu_compound("tea","house"),
  create_cmu_compound("tea","time"),
  create_cmu_compound("tender","foot"),
  create_cmu_compound("thunder","clap"),
  create_cmu_compound("tin","foil"),
  create_cmu_compound("tooth","ache"),
  create_cmu_compound("top","side"),
  create_cmu_compound("trap","door"),
  create_cmu_compound("tumble","weed"),
  create_cmu_compound("under","lay"),
  create_cmu_compound("under","privileged"),
  create_cmu_compound("un","hand"),
  create_cmu_compound("un","romantic"),
  create_cmu_compound("un","screw"),
  create_cmu_compound("un","selfish"),
  create_cmu_compound("un","well"),
  create_cmu_compound("you","ten","sul"),
  create_cmu_compound("upper","cut"),
  create_cmu_compound("war","lock"),
  create_cmu_compound("watch","tower"),
  create_cmu_compound("wind","bag"),
  create_cmu_compound("window","sill"),
  create_cmu_compound("wind","pipe"),
  create_cmu_compound("worm","hole")
)
Epron[Epron$Word=="spitfire",]$P7<-"R" # like afire/backfire/crossfire/hellfire, 
                                       # not like bonfire/campfire/gunfire/wildfire
Epron[Epron$Word=="cabaab",]$Word<-"kebab"
Epron[Epron$Word=="dilldough",]$Word<-"dildo"
Epron[Epron$Word=="silenceer",]$Word<-"silencer"
Epron[Epron$Word=="snoty",]$Word<-"snotty"
Epron[Epron$Word=="youtensul",]$Word<-"utensil"
Epron<-subset(Epron,Word%in%unique(sort(c(as.character(Eaff$Word),as.character(E2aff$Word)))))
Epron[,2:21]<-sapply(Epron[,2:21],function(x) sub("[012]","",x))
Ephonemes<-unique(sort(unlist(Epron[,2:21])))
Ephonemes<-Ephonemes[Ephonemes!=""]
Emain<-merge(subset(Eaff,Word==tolower(Word)|Word%in%c("AIDS","TRUE","FALSE")),Epron)
Emain<-subset(Emain,Word!="aids")
Emain$Word<-tolower(Emain$Word)
E2aff$Word<-tolower(E2aff$Word)
Elex<-data.frame(Word=character(),LgWF=double(),LgCD=double(),NMorph=integer(),RT=double())

Eword<-unique(sort(c(Emain$Word,E2aff$Word)))
for(i in seq(1,length(Eword),500)) {

write(file="elex_input.txt",Eword[i:min(i+499,length(Eword))])

elex_result<-POST("http://elexicon.wustl.edu/query14/Query14do.asp",
  encode="form",
  body=list(
            List="FILE",
            Field="LgSUBTLWF",
            Field="LgSUBTLCD",
            Field="NMorph",
            Field="I_NMG_Mean_RT",
            scope="FULELP",
            DIST="BROWSER"
           ),
  add_headers(Referer="http://elexicon.wustl.edu/query14/query14.asp")
)
substr(rawToChar(content(elex_result,"raw")),100,150)
mcook<-cookies(elex_result)$value
names(mcook)<-cookies(elex_result)$name
elex_result<-POST("http://elexicon.wustl.edu/query14/Query14FILE.asp",
  encode="multipart",
  body=list(
            oFile=upload_file("elex_input.txt")
           
           ),
  add_headers(Referer="http://elexicon.wustl.edu/query14/query14do.asp"),
  set_cookies(mcook)
)
elexinfo<-strsplit(rawToChar(content(elex_result,"raw")),"<TR")
elexinfo<-elexinfo[[1]][grep(elexinfo[[1]],pattern="<TD>1</TD>",fixed=T)]
elexinfo<-t(sapply(elexinfo,function(x){r<-strsplit(x,"</TD>",fixed=T);sub("<TD>","",r[[1]][2:6])}))
elexinfo[,5]<-sub(",","",elexinfo[,5])
elexinfo<-data.frame(Word=elexinfo[,1],LgWF=as.numeric(elexinfo[,2]),LgCD=as.numeric(elexinfo[,3]),NMorph=as.numeric(elexinfo[,4]),RT=as.numeric(elexinfo[,5]))
rownames(elexinfo)<-elexinfo[,1]
elexinfo$Word<-tolower(elexinfo$Word)
Elex<-rbind(Elex,elexinfo)
}
Elex[is.na(Elex$LgWF),]$LgWF<-0 # LgWF is log10(WF+1), log10(0+1)==0
Elex[is.na(Elex$LgCD),]$LgCD<-0
rm(elexinfo)

#subtlex<-GET("https://www.ugent.be/pp/experimentele-psychologie/en/research/documents/subtlexus/subtlexus3.zip/at_download/file",add_headers(Referer="https://www.ugent.be/pp/experimentele-psychologie/en/research/documents/subtlexus/subtlexus3.zip"))
#writeBin(content(subtlex,"raw"),"subtlex.zip")
#unzip("subtlex.zip")
#subtlex<-read.xlsx("SUBTLEXusExcel2007.xlsx")
#subtlex$Word<-tolower(subtlex$Word)

Emain<-merge(Emain,Elex)

Econsonants<-c("B","CH","D","DH","F","G","HH","JH","K","L","M","N","NG",
               "P","R","S","SH","T","TH","V","W","Y","Z","ZH")
Ecounts<-t(apply(Emain[,66:81],1,function(x) table(factor(x,levels=Ephonemes))))
EFirst<-Emain[,66]
Emain[,66:81][Emain[,66:81]==""]<-NA
ELast<-apply(Emain[,66:81],1,function(x) {r<-rev(x[!is.na(x)]); c(r,rep(NA,16-length(r)))})[1,]
Emain$Nphonemes<-apply(Ecounts,1,sum)
Emain$Ncons<-apply(data.frame(Ecounts)[Econsonants],1,sum)
Emain$Nvows<-Emain$Nphonemes-Emain$Ncons
Emain$Length<-nchar(Emain$Word)
EPF<-data.frame(front=apply(as.data.frame(Ecounts)[c("IY","IH","EY","EH","AE")],1,sum))
EPF$central<-apply(as.data.frame(Ecounts)[c("AH","ER","AA","AY","AW")],1,sum)
EPF$back<-apply(as.data.frame(Ecounts)[c("UW","UH","OW","OY","AO")],1,sum)
EPF$high<-apply(as.data.frame(Ecounts)[c("IY","IH","UW","UH")],1,sum)
EPF$mid<-apply(as.data.frame(Ecounts)[c("EY","EH","AH","ER","OW")],1,sum)
EPF$low<-apply(as.data.frame(Ecounts)[c("AE","AA","AY","AW","OY","AO")],1,sum)
EPF$bilabial<-apply(as.data.frame(Ecounts)[c("P","B","M","W")],1,sum)
EPF$labiodental<-apply(as.data.frame(Ecounts)[c("F","V")],1,sum)
EPF$linguodental<-apply(as.data.frame(Ecounts)[c("TH","DH")],1,sum)
EPF$alveolar<-apply(as.data.frame(Ecounts)[c("S","Z","T","D","N","L")],1,sum)
EPF$palatal<-apply(as.data.frame(Ecounts)[c("SH","ZH","CH","JH","R")],1,sum)
EPF$velar<-apply(as.data.frame(Ecounts)[c("K","G","NG")],1,sum)
EPF$glottal<-apply(as.data.frame(Ecounts)[c("HH")],1,sum)
EPF$stop<-apply(as.data.frame(Ecounts)[c("P","T","K","B","D","G")],1,sum)
EPF$affricate<-apply(as.data.frame(Ecounts)[c("CH","JH")],1,sum)
EPF$fricative<-apply(as.data.frame(Ecounts)[c("F","V","DH","TH","S","Z","SH","ZH","HH")],1,sum)
EPF$nasal<-apply(as.data.frame(Ecounts)[c("N","M","NG")],1,sum)
EPF$liquid<-apply(as.data.frame(Ecounts)[c("L","R")],1,sum)
EPF$glide<-apply(as.data.frame(Ecounts)[c("W","JH")],1,sum)
EPF$voiced<-apply(as.data.frame(Ecounts)[c("B","D","G","V","DH","Z","JH","M","N","NG","W","JH","L","R","Y")],1,sum)
EPF$voiceless<-apply(as.data.frame(Ecounts)[c("P","T","K","F","TH","S","SH","HH","CH")],1,sum)

colnames(Emain)[3]<-"Valence"
colnames(Emain)[6]<-"Arousal"

E2main<-merge(E2aff,Epron)
E2main<-merge(E2main,Elex)
E2counts<-t(apply(E2main[,7:26],1,function(x) table(factor(x,levels=Ephonemes))))
E2main$Nphonemes<-apply(E2counts,1,sum)
E2main$Ncons<-apply(data.frame(E2counts)[Econsonants],1,sum)
E2main$Nvows<-E2main$Nphonemes-E2main$Ncons
E2main$Length<-nchar(E2main$Word)



Rastle<-GET("https://docs.wixstatic.com/ugd/bcf054_0b2bbb6d8cbaa3d666d41b3e35bcfa50.pdf")
writeBin(content(Rastle,"raw"),con="Rastle.pdf")
pdf_text("Rastle.pdf")[7]->p1089
ROT<-substr(strsplit(p1089,"\r\n")[[1]][7:30],1,75)
ROT<-sub("\u5170/","sh/",ROT)
ROT<-sub("tsh","ch",ROT)
ROT<-sub("\u242a","th",ROT)
ROT<-sub("ð","dh",ROT)
ROT<-sub("d\002","jh",ROT)
ROT<-sub("\r","",ROT)
ROT<-sub("/j/","/y/",ROT)
ROT<-sub("/h/","/hh/",ROT)
ROT<-t(sapply(strsplit(ROT,"   *"),function(x) c(x,rep("",4-length(x)))))
ROT<-subset(ROT,ROT[,2]!="")
ROT<-data.frame(Phoneme=toupper(sub(".*/(.*)/.*","\\1",ROT[,2])),Offset=as.numeric(ROT[,3])+as.numeric(ROT[,4]))

EMControlForWhole<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,Emain)
EMWhole<-lm(Valence~Length+LgWF+LgCD+Arousal+Ecounts,Emain) # NVows, NCons are redundant with Ecounts
EMTable<-create_contrast_coefs(Emain,Ecounts)

EMWholeLessLength<-lm(Valence~LgWF+LgCD+Arousal+Ecounts,Emain)
EMPhonetic<-lm(Valence~Length+LgWF+LgCD+Arousal+as.matrix(EPF),Emain)

EMFirst<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+EFirst,Emain)
EMLast<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+ELast,Emain)

EMFirstTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+EFirst,Emain))[[4]]
EMLastTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+ELast,Emain))[[4]]
EMRT<-lm(RT~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+cent(Valence)+EFirst,Emain)                                         
EMRTTable<-summary(EMRT)[[4]]

EMRT<-lm(RT~
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+cent(Valence)+EFirst,Emain)                                         
EMRTF<-summary(EMRT)$fstatistic
EComboTable<-subset(merge(EMFirstTable[,1],EMRTTable[,1],by=0),grepl("First",Row.names))
EComboTableNoZH<-subset(EComboTable,!grepl("ZH",Row.names))
colnames(EComboTableNoZH)<-c("Phoneme","Valence","Latency")
EOffsetComboTable<-merge(data.frame(row.names=paste("EFirst",ROT$Phoneme,sep=""),ROT),EMFirstTable[,1],by=0)

splithalf<-function() {
  subchoose<-runif(dim(Emain)[1]); 
  subchoose<-subchoose>median(subchoose) ; 

  ESub<-subset(Emain,subchoose);
  ESubW<-subset(Ecounts,subchoose); 
  fulltab1<-create_contrast_coefs(ESub,ESubW)$phonemes

  ESub<-subset(Emain,!subchoose);
  ESubW<-subset(Ecounts,!subchoose); 
  fulltab2<-create_contrast_coefs(ESub,ESubW)$phonemes

  cor(fulltab1[,1],fulltab2[,1])
}

splithalves<-replicate(1000,splithalf())

EmonoL<-Emain$NMorph==1
EmonoL[is.na(EmonoL)]<-F
EMMonoControlForWhole<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,Emain[EmonoL,])
EMMonoWhole<-lm(Valence~Length+LgWF+LgCD+Arousal+Ecounts[EmonoL,],Emain[EmonoL,]) # NVows, NCons are redundant with Ecounts
EMMonoTable<-create_contrast_coefs(Emain[EmonoL,],Ecounts[EmonoL,])

E2MControlForWhole<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,E2main)
E2MWhole<-lm(Valence~Length+LgWF+LgCD+Arousal+E2counts,E2main) # NVows, NCons are redundant with Ecounts
E2MTable<-create_contrast_coefs(E2main,E2counts)

EcommonL<-Emain$Word%in%E2main$Word
E2commonL<-E2main$Word%in%Emain$Word

EMcommonControl<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,Emain[EcommonL,])
E2McommonControl<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,E2main[E2commonL,])

EMcommon<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+Ecounts[EcommonL,],Emain[EcommonL,])
E2Mcommon<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+E2counts[E2commonL,],E2main[E2commonL,])



EcommonTable<-create_contrast_coefs(Emain[EcommonL,],Ecounts[EcommonL,])
E2commonTable<-create_contrast_coefs(E2main[E2commonL,],E2counts[E2commonL,])

ElongL<-!is.na(Emain$P5)
EMControlForPositions<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,Emain[ElongL,])
EMP1<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P1,Emain[ElongL,])
EMP2<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P2,Emain[ElongL,])
EMP3<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P3,Emain[ElongL,])
EMP4<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P4,Emain[ElongL,])
EMP5<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P5,Emain[ElongL,])

EFMControl<-lm(LgWF~Length+Nvows+Ncons+Arousal,Emain)
EFMFirst<-lm(LgWF~Length+Nvows+Ncons+Arousal+EFirst,Emain)
EFMLast<-lm(LgWF~Length+Nvows+Ncons+Arousal+ELast,Emain)

EMINTControl<-lm(cent((9-Valence)*(Arousal))~Length+Nvows+Ncons+LgWF+LgCD+cent(Valence)+cent(Arousal),Emain)
EMINTFirst<-lm(cent(cent(9-Valence)*cent(Arousal))~0+cent(Length)+cent(Ncons)+cent(Nvows)+cent(LgWF)+cent(LgCD)+cent(Valence)+cent(Arousal)+EFirst,Emain) 
EMINTTable<-summary(EMINTFirst)[[4]]
EMINTCompTable<-merge(round(EMFirstTable[,c(1,4)],3),round(EMINTTable[,c(1,4)],3),by=0)
EMINTFirst<-lm(cent((9-Valence)*(Arousal))~EFirst+Length+LgWF+LgCD+Ncons+Nvows+cent(Valence)+cent(Arousal),Emain) 


EIPA<-rbind(
 data.frame(stringsAsFactors=F,
   CMU=c("AA",    "AE",   "AH"    ,"AO",    "AW",    "AY"),
   IPA=c("\u251:","\ue6" ,"\u28c" ,"\u254:","a\u28a","a\u26a")
 ),
 data.frame(stringsAsFactors=F,
   CMU=c("B","CH",         "D","DH","EH",  "ER",   "EY",    "F"),
   IPA=c("b","t\u361\u283","d","\uf0","\u25b","\u25d:","e\u26a","f")
 ),
 data.frame(stringsAsFactors=F,
   CMU=c("G","HH","IH",   "IY","JH",         "K","L","M","N","NG","OW"),
   IPA=c("g","h" ,"\u26a","i:","d\u361\u292","k","l","m","n","\u14b","o\u28a")
 ),
 data.frame(stringsAsFactors=F,
   CMU=c("OY",        "P","R","S","SH",   "T","TH",   "UH","UW","V","W","Y","Z","ZH"),
   IPA=c("\u254\u26a","p","r","s","\u283","t","\u3b8","\u28a","u:","v","w","j","z","\u292")
 )
)
EIPA$IPA<-sub(":","\u2d0",EIPA$IPA)

EComboTableNoZH$Phoneme<-sub("EFirst","",EComboTableNoZH$Phoneme)
EComboTableNoZH$Phoneme<-EIPA$IPA[match(EComboTableNoZH$Phoneme,EIPA$CMU)]
rownames(EMFirstTable)<-sub("EFirst","",rownames(EMFirstTable))
rownames(EMLastTable)<-sub("ELast","",rownames(EMLastTable))

ST1Controls<-merge(all=T,by="Row.names",
  merge(all=T,by=0,suffixes=c("AllW-AllP","MonoMW-AllP"),
    round(EMTable$controls[,-2],3),round(EMMonoTable$controls[,-2],3)),
  merge(all=T,by=0,suffixes=c("AllW-FirstP","AllW-LastP"),
    round(EMFirstTable[1:6,-2],3),round(EMLastTable[1:6,-2],3))
)
rownames(ST1Controls)<-ST1Controls$Row.names
ST1Controls<-ST1Controls[,-1]
ST1Phonemes<-merge(all=T,by="Row.names",
  merge(all=T,by=0,suffixes=c("AllW-AllP","MonoMW-AllP"),
    round(EMTable$phonemes[,-2],3),round(EMMonoTable$phonemes[,-2],3)),
  merge(all=T,by=0,suffixes=c("AllW-FirstP","AllW-LastP"),
    round(EMFirstTable[-(1:6),-2],3),round(EMLastTable[-(1:6),-2],3))
)
rownames(ST1Phonemes)<-ST1Phonemes$Row.names
ST1Phonemes<-ST1Phonemes[,-1]

ST2Controls<-merge(all=T,by.x=0,by.y="Row.names",
  round(E2MTable$controls[,-2],3),
  merge(all=T,by=0,suffixes=c("Common-Adel","Common-Warr"),
    round(E2commonTable$controls,3),round(EcommonTable$controls,3))
)
rownames(ST2Controls)<-ST2Controls$Row.names
ST2Controls<-ST2Controls[,-1]

ST2Phonemes<-merge(all=T,by.x=0,by.y="Row.names",
  round(E2MTable$phonemes[,-2],3),
  merge(all=T,by=0,suffixes=c("Common-Adel","Common-Warr"),
    round(E2commonTable$phonemes[,-2],3),round(EcommonTable$phonemes[,-2],3))
)
rownames(ST2Phonemes)<-ST2Phonemes$Row.names
ST2Phonemes<-ST2Phonemes[,-1]


rownames(EMFirstTable)[!is.na(match(rownames(EMFirstTable),EIPA$CMU))]<-
  EIPA$IPA[match(rownames(EMFirstTable),EIPA$CMU)][!is.na(match(rownames(EMFirstTable),EIPA$CMU))]
rownames(EMLastTable)[!is.na(match(rownames(EMLastTable),EIPA$CMU))]<-
  EIPA$IPA[match(rownames(EMLastTable),EIPA$CMU)][!is.na(match(rownames(EMLastTable),EIPA$CMU))]
rownames(EMTable$phonemes)<-EIPA$IPA[match(rownames(EMTable$phonemes),EIPA$CMU)]
rownames(EMMonoTable$phonemes)<-EIPA$IPA[match(rownames(EMMonoTable$phonemes),EIPA$CMU)]
rownames(ST1Phonemes)<-EIPA$IPA[match(rownames(ST1Phonemes),EIPA$CMU)]
rownames(ST2Phonemes)<-EIPA$IPA[match(rownames(ST2Phonemes),EIPA$CMU)]
rownames(EMINTCompTable)<-EMINTCompTable$Row.names
EMINTCompTable<-EMINTCompTable[,-1]
rownames(EMINTCompTable)<-sub("EFirst","",rownames(EMINTCompTable))
rownames(EMINTCompTable)[!is.na(match(rownames(EMINTCompTable),EIPA$CMU))]<-
  EIPA$IPA[match(rownames(EMINTCompTable),EIPA$CMU)][!is.na(match(rownames(EMINTCompTable),EIPA$CMU))]


# SPANISH

download.file("https://static-content.springer.com/esm/art%3A10.3758%2Fs13428-015-0700-2/MediaObjects/13428_2015_700_MOESM1_ESM.csv",destfile="Stadthagen.csv")
read.csv("Stadthagen.csv")->Saff
sub("\\*","",Saff$Word)->Saff$Word
write.table(Saff[1:9000,2],file="Sitems1.txt",col.names=F,row.names=F,quote=F)
write.table(Saff[-(1:9000),2],file="Sitems2.txt",col.names=F,row.names=F,quote=F)
colnames(Saff)[3]<-"Valence"
colnames(Saff)[6]<-"Arousal"


espal_result<-POST("http://www.bcbl.eu/databases/espal/index.php",
  encode="form",
  body=list(
            database="subtitles"
           
           )
)
mcook<-cookies(espal_result)$value
names(mcook)<-cookies(espal_result)$name
#content(espal_result,"text")

espal_result<-POST("http://www.bcbl.eu/databases/espal/w2iout.php",
  encode="multipart",
  body=list(
            MAX_FILE_SIZE="1000000",
            words_file=upload_file("Sitems1.txt"),
            'idxname[]'="log_frq"
            
           ),
  set_cookies(mcook)
)

content(espal_result,"text")->Shtml
write(Shtml,file="S.html")
rm("Shtml")
Stab<-readLines("S.html")
Stab<-Stab[grep("<table class=\"items\"",Stab)]
Stab<-strsplit(Stab,"<tr>")[[1]]
strsplit(Stab,"<td[^>]*>")->Stab
t(data.frame(lapply(Stab,function(x) sub("</td>.*","",x))))[-(1:2),-1]->Stab
Stab<-as.data.frame(Stab)
dimnames(Stab)[[1]]<-as.character(1:(dim(Stab)[1]))
Stab[,2]<-as.character(Stab[,2])
Stab[,2]<-as.numeric(Stab[,2])
colnames(Stab)<-c("Word","LgWF")
Stab->StabWF

espal_result<-POST("http://www.bcbl.eu/databases/espal/index.php",
  encode="form",
  body=list(
            database="subtitles_cdm"
           
           )
)
mcook<-cookies(espal_result)$value
names(mcook)<-cookies(espal_result)$name
#content(espal_result,"text")

espal_result<-POST("http://www.bcbl.eu/databases/espal/w2iout.php",
  encode="multipart",
  body=list(
            MAX_FILE_SIZE="1000000",
            words_file=upload_file("Sitems1.txt"),
            'idxname[]'="log_frq"
            
           ),
  set_cookies(mcook)
)

content(espal_result,"text")->Shtml
write(Shtml,file="S.html")
rm("Shtml")
Stab<-readLines("S.html")
Stab<-Stab[grep("<table class=\"items\"",Stab)]
Stab<-strsplit(Stab,"<tr>")[[1]]
strsplit(Stab,"<td[^>]*>")->Stab
t(data.frame(lapply(Stab,function(x) sub("</td>.*","",x))))[-(1:2),-1]->Stab
Stab<-as.data.frame(Stab)
dimnames(Stab)[[1]]<-as.character(1:(dim(Stab)[1]))
Stab[,2]<-as.character(Stab[,2])
Stab[,2]<-as.numeric(Stab[,2])
colnames(Stab)<-c("Word","LgCD")
Stab->StabCD
rm("Stab")
espal_result<-POST("http://www.bcbl.eu/databases/espal/index.php",
  encode="form",
  body=list(
            database="written"
           
           )
)
mcook<-cookies(espal_result)$value
names(mcook)<-cookies(espal_result)$name
#content(espal_result,"text")

espal_result<-POST("http://www.bcbl.eu/databases/espal/w2iout.php",
  encode="multipart",
  body=list(
            MAX_FILE_SIZE="1000000",
            words_file=upload_file("Sitems1.txt"),
            'idxname[]'="es_phon_structure"
            
           ),
  set_cookies(mcook)
)

content(espal_result,"text")->Shtml
write(Shtml,file="S.html")
rm("Shtml")
Stab<-readLines("S.html")
Stab<-Stab[grep("<table class=\"items\"",Stab)]
Stab<-strsplit(Stab,"<tr>")[[1]]
strsplit(Stab,"<td[^>]*>")->Stab
t(data.frame(lapply(Stab,function(x) sub("</td>.*","",x))))[-(1:2),-1]->Stab
Stab<-as.data.frame(Stab)
dimnames(Stab)[[1]]<-as.character(1:(dim(Stab)[1]))
Stab[,2]<-as.character(Stab[,2])
colnames(Stab)<-c("Word","Pron")
Stab->StabPron
rm("Stab")
merge(merge(merge(Saff,StabWF,by="Word"),StabCD,by="Word"),StabPron,by="Word")->Stab1

espal_result<-POST("http://www.bcbl.eu/databases/espal/index.php",
  encode="form",
  body=list(
            database="subtitles"
           
           )
)
mcook<-cookies(espal_result)$value
names(mcook)<-cookies(espal_result)$name
#content(espal_result,"text")

espal_result<-POST("http://www.bcbl.eu/databases/espal/w2iout.php",
  encode="multipart",
  body=list(
            MAX_FILE_SIZE="1000000",
            words_file=upload_file("Sitems2.txt"),
            'idxname[]'="log_frq"
            
           ),
  set_cookies(mcook)
)

content(espal_result,"text")->Shtml
write(Shtml,file="S.html")
rm("Shtml")
Stab<-readLines("S.html")
Stab<-Stab[grep("<table class=\"items\"",Stab)]
Stab<-strsplit(Stab,"<tr>")[[1]]
strsplit(Stab,"<td[^>]*>")->Stab
t(data.frame(lapply(Stab,function(x) sub("</td>.*","",x))))[-(1:2),-1]->Stab
Stab<-as.data.frame(Stab)
dimnames(Stab)[[1]]<-as.character(1:(dim(Stab)[1]))
Stab[,2]<-as.character(Stab[,2])
Stab[,2]<-as.numeric(Stab[,2])
colnames(Stab)<-c("Word","LgWF")
Stab->StabWF

espal_result<-POST("http://www.bcbl.eu/databases/espal/index.php",
  encode="form",
  body=list(
            database="subtitles_cdm"
           
           )
)
mcook<-cookies(espal_result)$value
names(mcook)<-cookies(espal_result)$name
#content(espal_result,"text")

espal_result<-POST("http://www.bcbl.eu/databases/espal/w2iout.php",
  encode="multipart",
  body=list(
            MAX_FILE_SIZE="1000000",
            words_file=upload_file("Sitems2.txt"),
            'idxname[]'="log_frq"
            
           ),
  set_cookies(mcook)
)

content(espal_result,"text")->Shtml
write(Shtml,file="S.html")
rm("Shtml")
Stab<-readLines("S.html")
Stab<-Stab[grep("<table class=\"items\"",Stab)]
Stab<-strsplit(Stab,"<tr>")[[1]]
strsplit(Stab,"<td[^>]*>")->Stab
t(data.frame(lapply(Stab,function(x) sub("</td>.*","",x))))[-(1:2),-1]->Stab
Stab<-as.data.frame(Stab)
dimnames(Stab)[[1]]<-as.character(1:(dim(Stab)[1]))
Stab[,2]<-as.character(Stab[,2])
Stab[,2]<-as.numeric(Stab[,2])
colnames(Stab)<-c("Word","LgCD")
Stab->StabCD
rm("Stab")
espal_result<-POST("http://www.bcbl.eu/databases/espal/index.php",
  encode="form",
  body=list(
            database="written"
           
           )
)
mcook<-cookies(espal_result)$value
names(mcook)<-cookies(espal_result)$name
#content(espal_result,"text")

espal_result<-POST("http://www.bcbl.eu/databases/espal/w2iout.php",
  encode="multipart",
  body=list(
            MAX_FILE_SIZE="1000000",
            words_file=upload_file("Sitems2.txt"),
            'idxname[]'="es_phon_structure"
            
           ),
  set_cookies(mcook)
)

content(espal_result,"text")->Shtml
write(Shtml,file="S.html")
rm("Shtml")
Stab<-readLines("S.html")
Stab<-Stab[grep("<table class=\"items\"",Stab)]
Stab<-strsplit(Stab,"<tr>")[[1]]
strsplit(Stab,"<td[^>]*>")->Stab
t(data.frame(lapply(Stab,function(x) sub("</td>.*","",x))))[-(1:2),-1]->Stab
Stab<-as.data.frame(Stab)
dimnames(Stab)[[1]]<-as.character(1:(dim(Stab)[1]))
Stab[,2]<-as.character(Stab[,2])
colnames(Stab)<-c("Word","Pron")
Stab->StabPron
rm("Stab")
merge(merge(merge(Saff,StabWF,by="Word"),StabCD,by="Word"),StabPron,by="Word")->Stab2

rbind(Stab1,Stab2)->Stab
rm("Stab1","Stab2")
Smain<-subset(Stab,Pron!="")
Smain[is.na(Smain$LgWF),]$LgWF<-0
Smain[is.na(Smain$LgCD),]$LgCD<-0
rm(Stab)
Sphonemes<-unique(sort(unlist(strsplit(as.character(Smain$Pron),split=""))))

Smain$P1=substr(Smain$Pron,1,1)
Smain$P2=substr(Smain$Pron,2,2)
Smain$P3=substr(Smain$Pron,3,3)
Smain$P4=substr(Smain$Pron,4,4)
Smain$P5=substr(Smain$Pron,5,5)
Smain$P1[Smain$P1==""]<-NA
Smain$P2[Smain$P2==""]<-NA
Smain$P3[Smain$P3==""]<-NA
Smain$P4[Smain$P4==""]<-NA
Smain$P5[Smain$P5==""]<-NA
SFirst<-Smain$P1
SLast<-substr(Smain$Pron,nchar(Smain$Pron),nchar(Smain$Pron))
Scounts<-t(sapply(strsplit(as.character(Smain$Pron),split=""),function(x) table(factor(x,levels=Sphonemes))))
Sconsonants<-c("b","B","C","d","D","f","g","G","H","j","J","k","l","L","m","n",
               "N","p","r","R","s","t","T","w","x","z")
Smain$Nphonemes<-apply(Scounts,1,sum)
Smain$Ncons<-apply(data.frame(Scounts)[Sconsonants],1,sum)
Smain$Nvows<-Smain$Nphonemes-Smain$Ncons
Smain$Length<-nchar(Smain$Word)

SMControlForWhole<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,Smain)
SMWhole<-lm(Valence~Length+LgWF+LgCD+Arousal+Scounts,Smain) # NVows, NCons are redundant with Ecounts
SMTable<-create_contrast_coefs(Smain,Scounts)
SMFirstTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+SFirst,Smain))[[4]]
SMLastTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+SLast,Smain))[[4]]

SPF<-data.frame(bilabial=apply(as.data.frame(Scounts)[c("p","b","m","B")],1,sum))
SPF$labiodental<-apply(as.data.frame(Scounts)[c("f")],1,sum)
SPF$dental<-apply(as.data.frame(Scounts)[c("t","d","T","D")],1,sum)
SPF$alveolar<-apply(as.data.frame(Scounts)[c("n","s","z","l","R","r")],1,sum)
SPF$palatal<-apply(as.data.frame(Scounts)[c("J","C","L","H","j")],1,sum)
SPF$labiovelar<-apply(as.data.frame(Scounts)[c("w")],1,sum)
SPF$velar<-apply(as.data.frame(Scounts)[c("k","g","N","x","G")],1,sum)
SPF$plosive<-apply(as.data.frame(Scounts)[c("p","b","t","d","k","g")],1,sum)
SPF$nasal<-apply(as.data.frame(Scounts)[c("m","n","N","j")],1,sum)
SPF$fricative<-apply(as.data.frame(Scounts)[c("f","T","s","z","H","x")],1,sum)
SPF$affricate<-apply(as.data.frame(Scounts)[c("C")],1,sum)
SPF$lateral<-apply(as.data.frame(Scounts)[c("l","L")],1,sum)
SPF$trill<-apply(as.data.frame(Scounts)[c("r","R")],1,sum)
SPF$approximant<-apply(as.data.frame(Scounts)[c("B","D","G","j","w")],1,sum)
SPF$voiceless<-apply(as.data.frame(Scounts)[c("p","t","k","C","f","T","s","x")],1,sum)
SPF$voiced<-apply(as.data.frame(Scounts)[c("b","d","g","m","n","N","J","z","H","l","L","R","j","w","B","D","G","r")],1,sum)
SPF$open<-apply(as.data.frame(Scounts)[c("a")],1,sum)
SPF$mid<-apply(as.data.frame(Scounts)[c("o","e")],1,sum)
SPF$close<-apply(as.data.frame(Scounts)[c("i","u")],1,sum)
SPF$unrounded<-apply(as.data.frame(Scounts)[c("a","e","i")],1,sum)
SPF$rounded<-apply(as.data.frame(Scounts)[c("o","u")],1,sum)
SPF$front<-apply(as.data.frame(Scounts)[c("e","i")],1,sum)
SPF$central<-apply(as.data.frame(Scounts)[c("a")],1,sum)
SPF$back<-apply(as.data.frame(Scounts)[c("o","u")],1,sum)

SMPhonetic<-lm(Valence~Length+LgWF+LgCD+Arousal+as.matrix(SPF),Smain)

SMFirst<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+SFirst,Smain)
SMLast<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+SLast,Smain)

SlongL<-!is.na(Smain$P5)
SMControlForPositions<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,Smain[SlongL,])
SMP1<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P1,Smain[SlongL,])
SMP2<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P2,Smain[SlongL,])
SMP3<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P3,Smain[SlongL,])
SMP4<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P4,Smain[SlongL,])
SMP5<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+P5,Smain[SlongL,])

SFMControl<-lm(LgWF~Length+Nvows+Ncons+Arousal,Smain)
SFMFirst<-lm(LgWF~Length+Nvows+Ncons+Arousal+SFirst,Smain)
SFMLast<-lm(LgWF~Length+Nvows+Ncons+Arousal+SLast,Smain)
SIPA<-
data.frame(stringsAsFactors=F,
ESPAL=c("p","b","t","d","k","g","m","n","N","J","C","f",
"T","s","z","H","x","l","L","R",
"j","w","B","D","G","r","a","e","i","o","u"),
IPA=c("p","b","t","d","k","g","m","n","\u14b","\u272","t\u361\u283","f",
"\u3b8","s","z","\u29d","x","l","\u28e","r",
"j","w","\u3b2\u2d5","\uf0\u2d5","\u263\u2d5","\u27e","a","e","i","o","u")
)
SIPA$IPA<-sub(":","\u2d0",SIPA$IPA)

rownames(SMFirstTable)<-sub("SFirst","",rownames(SMFirstTable))
rownames(SMLastTable)<-sub("SLast","",rownames(SMLastTable))

ST3Controls<-merge(all=T,by.x=0,by.y="Row.names",
    round(SMTable$controls[,-2],3),
  merge(all=T,by=0,suffixes=c("FirstP","LastP"),
    round(SMFirstTable[1:6,-2],3),round(SMLastTable[1:6,-2],3))
)
rownames(ST3Controls)<-ST3Controls$Row.names
ST3Controls<-ST3Controls[,-1]
ST3Phonemes<-merge(all=T,by.x=0,by.y="Row.names",
    round(SMTable$phonemes[,-2],3),
  merge(all=T,by=0,suffixes=c("FirstP","LastP"),
    round(SMFirstTable[-(1:6),-2],3),round(SMLastTable[-(1:6),-2],3))
)

rownames(ST3Phonemes)<-ST3Phonemes$Row.names
ST3Phonemes<-ST3Phonemes[,-1]
rownames(ST3Phonemes)<-SIPA$IPA[match(rownames(ST3Phonemes),SIPA$ESPAL)]

rownames(SMFirstTable)[!is.na(match(rownames(SMFirstTable),SIPA$ESPAL))]<-
  SIPA$IPA[match(rownames(SMFirstTable),SIPA$ESPAL)][!is.na(match(rownames(SMFirstTable),SIPA$ESPAL))]
rownames(SMLastTable)[!is.na(match(rownames(SMLastTable),SIPA$ESPAL))]<-
  SIPA$IPA[match(rownames(SMLastTable),SIPA$ESPAL)][!is.na(match(rownames(SMLastTable),SIPA$ESPAL))]
rownames(SMTable$phonemes)<-SIPA$IPA[match(rownames(SMTable$phonemes),SIPA$ESPAL)]


# DUTCH

Mo<-GET("https://static-content.springer.com/esm/art%3A10.3758%2Fs13428-012-0243-8/MediaObjects/13428_2012_243_MOESM1_ESM.xlsx")
writeBin(content(Mo,"raw"),"Moors.xlsx")
rm("Mo")
Daff<-read.xlsx("Moors.xlsx",1,startRow=2)
SUBTLEX_NL<-GET("http://crr.ugent.be/subtlex-nl/SUBTLEX-NL.Rdata")
writeBin(content(SUBTLEX_NL,"raw"),"SUBTLEX-NL.Rdata")
rm(SUBTLEX_NL)
attach("SUBTLEX-NL.Rdata")
Daff[Daff$Words=="autononoom",]$Words<-"autonoom"
Daff[Daff$Words=="alcholisme",]$Words<-"alcoholisme"
Daff[Daff$Words=="onsympatiek",]$Words<-"onsympathiek"
Daff$Words<-iconv(Daff$Words,from="UTF-8","ASCII//TRANSLIT")
Daff$Words<-tolower(Daff$Words)
colnames(Daff)[3]<-"Valence"
colnames(Daff)[6]<-"Arousal"
dpw<-read.table("dpw.cd",sep="\\",fill=T,quote=NULL)
Dpron<-data.frame(stringsAsFactors=F,Word=tolower(dpw$V2),Pron=gsub("[\'\"-]","",dpw$V5))
Dpron<-subset(Dpron,Pron!="")
Dpron<-subset(Dpron,!duplicated(Word))
colnames(Daff)[1]<-"Word"
Dmain<-merge(Daff,Dpron,by="Word")
colnames(subtlex.nl.full)[8]<-"LgWF"
colnames(subtlex.nl.full)[10]<-"LgCD"
Dmain<-merge(Dmain,subtlex.nl.full,all.x=T)
Dmain[is.na(Dmain$LgWF),]$LgWF<-0
Dmain[is.na(Dmain$LgCD),]$LgCD<-0
detach()
rm(Dpron)
Dphonemes<-unique(sort(unlist(strsplit(Dmain$Pron,split=""))))
DFirst<-substr(Dmain$Pron,1,1)
DLast<-substr(Dmain$Pron,nchar(Dmain$Pron),nchar(Dmain$Pron))
Dcounts<-t(sapply(strsplit(Dmain$Pron,split=""),function(x) table(factor(x,levels=Dphonemes))))
Dconsonants<-c("p","b","t","d","k","g","N","m","n","l","r","r","v","s","z",
               "S","Z","j","x","G","h","w","_")

Dmain$Nphonemes<-apply(Dcounts,1,sum)
Dmain$Ncons<-apply(data.frame(Dcounts,check.names=F)[Dconsonants],1,sum)
Dmain$Nvows<-Dmain$Nphonemes-Dmain$Ncons
Dmain$Length<-nchar(Dmain$Word)

DMControlForWhole<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,Dmain)
DMWhole<-lm(Valence~Length+LgWF+LgCD+Arousal+Dcounts,Dmain) # NVows, NCons are redundant with Ecounts
DMTable<-create_contrast_coefs(Dmain,Dcounts)

DPF<-data.frame(bilabial=apply(as.data.frame(Dcounts)[c("p","b","m","w")],1,sum))
DPF$labiodental<-apply(as.data.frame(Dcounts)[c("f","v")],1,sum)
DPF$alveolar<-apply(as.data.frame(Dcounts)[c("t","d","s","z","n","l","r")],1,sum)
DPF$palatal<-apply(as.data.frame(Dcounts)[c("S","Z","_")],1,sum)
DPF$velar<-apply(as.data.frame(Dcounts)[c("g","x","N","j","k","G")],1,sum)
DPF$glottal<-apply(as.data.frame(Dcounts)[c("h")],1,sum)
DPF$stop<-apply(as.data.frame(Dcounts)[c("p","b","t","d","g","k")],1,sum)
DPF$fricative<-apply(as.data.frame(Dcounts)[c("f","v","s","z","S","x","G","h","Z")],1,sum)
DPF$affricate<-apply(as.data.frame(Dcounts)[c("_")],1,sum)
DPF$nasal<-apply(as.data.frame(Dcounts)[c("m","n","N")],1,sum)
DPF$rothic<-apply(as.data.frame(Dcounts)[c("r")],1,sum)
DPF$approximant<-apply(as.data.frame(Dcounts)[c("j","l","w")],1,sum)
DPF$voiceless<-apply(as.data.frame(Dcounts)[c("p","t","k","f","s","S","x","h","j")],1,sum)
DPF$voiced<-apply(as.data.frame(Dcounts)[c("b","d","g","v","z","Z","_","m","n","N","l","r","w","G")],1,sum)
DPF$close<-apply(as.data.frame(Dcounts)[c("I","}","i","y","u")],1,sum) #"(","!" do not occur
DPF$mid<-apply(as.data.frame(Dcounts)[c("K","E","@","O","e","|","o",")","*","<","L")],1,sum)
DPF$open<-apply(as.data.frame(Dcounts)[c("M","A","a")],1,sum)
DPF$unrounded<-apply(as.data.frame(Dcounts)[c("K","I","E","@","i","e",")","a")],1,sum) #"!" does not occur
DPF$rounded<-apply(as.data.frame(Dcounts)[c("M","}","O","A","u","y","o","|","<","L")],1,sum) #"(" does not occur
DPF$front<-apply(as.data.frame(Dcounts)[c("K","I","E","}","i","e",")","a","y","|","*","L")],1,sum) #"(","!" do not occur
DPF$central<-apply(as.data.frame(Dcounts)[c("@")],1,sum)
DPF$back<-apply(as.data.frame(Dcounts)[c("M","o","A","u","<","O")],1,sum)
DPF$short<-apply(as.data.frame(Dcounts)[c("K","M","I","E","}","@","O","A","L")],1,sum)
DPF$long<-apply(as.data.frame(Dcounts)[c("i","y","u","e","|","o",")","*","a","<")],1,sum) #"(","!" do not occur

DMPhonetic<-lm(Valence~Length+LgWF+LgCD+Arousal+as.matrix(DPF),Dmain)

DMFirst<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+DFirst,Dmain)
DMLast<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+DLast,Dmain)
DMFirstTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+DFirst,Dmain))[[4]]
DMLastTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+DLast,Dmain))[[4]]

DIPA<-rbind(
 data.frame(stringsAsFactors=F,
   DISC=c("O",    "A",    "E",    "I",    "G",    "Z",    "S",    "N"),
   IPA =c("\u254","\u251","\u25b","\u26a","\u263","\u292","\u283","\u14b")
 ),
 data.frame(stringsAsFactors=F,
   DISC=c("K",     "M",     "L",     ")",     "@",     "_" ,        "|"),
   IPA =c("\u25bi","\u251u","\u153y","\u25b:","\u259","d\u361\u292","\u00f8:")
 ),
 data.frame(stringsAsFactors=F,
   DISC=c("}",    "<",     "*",     "a", "b","d","e", "f","g","h","i", "j"),
   IPA =c("\u289","\u252:","\u153:","a:","b","d","e:","f","g","h","i:","j")
 ),
 data.frame(stringsAsFactors=F,
   DISC=c("k","l","m","n","o", "p","r","s","t","u", "v","w",    "x","y", "z"),
   IPA =c("k","l","m","n","o:","p","r","s","t","u:","v","\u28b","x","y:","z")
 )
)
DIPA$IPA<-sub(":","\u2d0",DIPA$IPA)

rownames(DMFirstTable)<-sub("DFirst","",rownames(DMFirstTable))
rownames(DMLastTable)<-sub("DLast","",rownames(DMLastTable))

ST4Controls<-merge(all=T,by.x=0,by.y="Row.names",
    round(DMTable$controls[,-2],3),
  merge(all=T,by=0,suffixes=c("FirstP","LastP"),
    round(DMFirstTable[1:6,-2],3),round(DMLastTable[1:6,-2],3))
)
rownames(ST4Controls)<-ST4Controls$Row.names
ST4Controls<-ST4Controls[,-1]
ST4Phonemes<-merge(all=T,by.x=0,by.y="Row.names",
    round(DMTable$phonemes[,-2],3),
  merge(all=T,by=0,suffixes=c("FirstP","LastP"),
    round(DMFirstTable[-(1:6),-2],3),round(DMLastTable[-(1:6),-2],3))
)

rownames(ST4Phonemes)<-ST4Phonemes$Row.names
ST4Phonemes<-ST4Phonemes[,-1]
rownames(ST4Phonemes)<-DIPA$IPA[match(rownames(ST4Phonemes),DIPA$DISC)]

rownames(DMFirstTable)[!is.na(match(rownames(DMFirstTable),DIPA$DISC))]<-
  DIPA$IPA[match(rownames(DMFirstTable),DIPA$DISC)][!is.na(match(rownames(DMFirstTable),DIPA$DISC))]
rownames(DMLastTable)[!is.na(match(rownames(DMLastTable),DIPA$DISC))]<-
  DIPA$IPA[match(rownames(DMLastTable),DIPA$DISC)][!is.na(match(rownames(DMLastTable),DIPA$DISC))]
rownames(DMTable$phonemes)<-DIPA$IPA[match(rownames(DMTable),DIPA$DISC)]

# GERMAN

Vo<-GET("http://www.ewi-psy.fu-berlin.de/einrichtungen/arbeitsbereiche/allgpsy/forschung/Download/BAWL-R.xls")
writeBin(content(Vo,"raw"),"Vo.xls")
rm("Vo")
xls2csv_pwd("Vo.xls","Vo.csv",1,"bawl")
Gaff<-read.csv("Vo.csv")
Gaff$Word<-sub("ä","ae",Gaff$WORD_LOWER)
Gaff$Word<-sub("ö","oe",Gaff$Word)
Gaff$Word<-sub("ü","ue",Gaff$Word)
Gaff$Word<-sub("ß","ss",Gaff$Word)
colnames(Gaff)[6]<-"Arousal"
colnames(Gaff)[4]<-"Valence"
gpw<-read.table("gpw.cd",sep="\\",fill=T,quote=NULL)
GPron<-data.frame(stringsAsFactors=F,Word=tolower(gpw$V2),Pron=gsub("[\'\"-]","",gpw$V5))
GPron<-subset(GPron,!duplicated(Word))
SUBTLEX_DE<-GET("http://crr.ugent.be/SUBTLEX-DE/SUBTLEX-DE%20raw%20file.xlsx")
writeBin(content(SUBTLEX_DE,"raw"),"subDE.xlsx")
rm(SUBTLEX_DE)
subtlex_de<-read.xlsx("subDE.xlsx",1)
write.csv(file="SD.csv",subtlex_de)
subtlex_de<-read.csv("SD.csv",encoding="UTF-8")
subtlex_de$Word<-tolower(subtlex_de$Word)
subtlex_de$Word<-sub("ä","ae",subtlex_de$Word)
subtlex_de$Word<-sub("ö","oe",subtlex_de$Word)
subtlex_de$Word<-sub("ü","ue",subtlex_de$Word)
subtlex_de$Word<-sub("ß","ss",subtlex_de$Word)
subtlex_de<-subset(subtlex_de,!duplicated(Word))
subtlex_de$LgWF<-log(subtlex_de$FREQcount)
subtlex_de$LgCD<-rep(0,dim(subtlex_de)[1]) # constant will always be dropped
Gmain<-merge(Gaff,GPron)
rm(GPron)
Gmain<-merge(Gmain,subtlex_de,all.x=T)
Gmain[is.na(Gmain$LgWF),]$LgWF<-0
Gmain[is.na(Gmain$LgCD),]$LgCD<-0
Gphonemes<-unique(sort(unlist(strsplit(Gmain$Pron,split=""))))
GFirst<-substr(Gmain$Pron,1,1)
GLast<-substr(Gmain$Pron,nchar(Gmain$Pron),nchar(Gmain$Pron))
Gcounts<-t(sapply(strsplit(Gmain$Pron,split=""),function(x) table(factor(x,levels=Gphonemes))))
download.file("https://www.mpib-berlin.mpg.de/pubdata/read/DeveL.RData",
              destfile="DeveL.RData")
attach("DeveL.RData")
write.csv(file="Devel.csv",data.frame(Word=nam.on$word,RT=nam.on$on.ya.m))
GRTs<-read.csv("Devel.csv",encoding="UTF-8")
GRTs$Word<-tolower(GRTs$Word)
GRTs$Word<-sub("ä","ae",GRTs$Word)
GRTs$Word<-sub("ö","oe",GRTs$Word)
GRTs$Word<-sub("ü","ue",GRTs$Word)
GRTs$Word<-sub("ß","ss",GRTs$Word)
detach()
Gmain<-merge(Gmain,GRTs,all.x=T,by="Word")
Gconsonants<-c("p","b","t","d","k","g","N","m","n","l","r","f","v","s","z",
               "S","Z","j","x","h","W","+","=","J","_")

Gmain$Nphonemes<-apply(Gcounts,1,sum)
Gmain$Ncons<-apply(data.frame(Gcounts,check.names=F)[Gconsonants],1,sum)
Gmain$Nvows<-Gmain$Nphonemes-Gmain$Ncons
Gmain$Length<-nchar(Gmain$Word)

GMControlForWhole<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,Gmain)
GMWhole<-lm(Valence~Length+LgWF+LgCD+Arousal+Gcounts,Gmain) # NVows, NCons are redundant with Ecounts
GMTable<-create_contrast_coefs(Gmain,Gcounts)

GPF<-data.frame(labial=apply(as.data.frame(Gcounts)[c("p","b","m","+","f","v")],1,sum))
GPF$alveolar<-apply(as.data.frame(Gcounts)[c("t","d","n","r","s","z","l","=")],1,sum)
GPF$palatal<-apply(as.data.frame(Gcounts)[c("j","Z","S","_","J")],1,sum)
GPF$velar<-apply(as.data.frame(Gcounts)[c("k","g","N","x")],1,sum)
GPF$glottal<-apply(as.data.frame(Gcounts)[c("h")],1,sum)
GPF$nasal<-apply(as.data.frame(Gcounts)[c("m","n","N")],1,sum)
GPF$plosive<-apply(as.data.frame(Gcounts)[c("p","t","k","b","d","g")],1,sum)
GPF$affricate<-apply(as.data.frame(Gcounts)[c("+","=","J","_")],1,sum)
GPF$fricative<-apply(as.data.frame(Gcounts)[c("s","z","S","Z","f","v","j","x","h")],1,sum)
GPF$lateral<-apply(as.data.frame(Gcounts)[c("l")],1,sum)
GPF$rhotic<-apply(as.data.frame(Gcounts)[c("r")],1,sum)
GPF$close<-apply(as.data.frame(Gcounts)[c("i","I","W","Y","u","B","X","U")],1,sum)
GPF$mid<-apply(as.data.frame(Gcounts)[c("e","E",")","/","^","0","@","|","o","O","~")],1,sum)
GPF$open<-apply(as.data.frame(Gcounts)[c("a","&","q")],1,sum)
GPF$front<-apply(as.data.frame(Gcounts)[c("i","I","W","Y","y","e","E",")","/","^","0","|","a","&")],1,sum)
GPF$central<-apply(as.data.frame(Gcounts)[c("@")],1,sum)
GPF$back<-apply(as.data.frame(Gcounts)[c("a","B","X","U","o","O","~","q")],1,sum)
GPF$short<-apply(as.data.frame(Gcounts)[c("I","Y","E","&","O","U","@","/")],1,sum)
GPF$long<-apply(as.data.frame(Gcounts)[c("i","a","u","y",")","e","|","W","B","X","^","q","0","~","o")],1,sum)
GPF$rounded<-apply(as.data.frame(Gcounts)[c("u","y","|","o","B","X","Y","/","O","U")],1,sum)
GPF$unrounded<-apply(as.data.frame(Gcounts)[c("i","a",")","e","W","I","E","&","@","^","q","0","~")],1,sum)

GMPhonetic<-lm(Valence~Length+LgWF+LgCD+Arousal+as.matrix(GPF),Gmain) 

GMFirst<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+GFirst,Gmain)
GMLast<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+GLast,Gmain)

GMFirstTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+GFirst,Gmain))[[4]]
GMLastTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+GLast,Gmain))[[4]]
                       
GMRT<-lm(RT~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+cent(Valence)+GFirst,Gmain)                  
GMRTTable<-summary(GMRT)[[4]]

GMRT<-lm(RT~
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+cent(Valence)+GFirst,Gmain)                  
GMRTF<-summary(GMRT)$fstatistic
GComboTable<-subset(merge(GMFirstTable[,1],GMRTTable[,1],by=0),grepl("First",Row.names))
colnames(GComboTable)<-c("Phoneme","Valence","Latency")
GIPA<-rbind(
 data.frame(stringsAsFactors=F,
   DISC=c("&",")",     "/",    "@",    "^",          "_",          "|"    ),
   IPA =c("a","\u25b:","\u153","\u259","\u153\u303:","d\u361\u292","\uf8:")
 ),
 data.frame(stringsAsFactors=F,
   DISC=c("~",     "+",      "=",      "0",    "a", "b","B", "d","e" ),
   IPA =c("\u252:","p\u0361f","t\u361s","\u36:","a:","b","au","d","e:")
 ),
 data.frame(stringsAsFactors=F,
   DISC=c("E",    "f","g","h","i", "I",    "j","J",          "k","l","m","n"),
   IPA =c("\u25b","f","g","h","i:","\u261","j","t\u361\u283","k","l","m","n")
 ),
 data.frame(stringsAsFactors=F,
   DISC=c("N",    "o", "O",    "p","q",          "r","s","S",    "t"),
   IPA =c("\u14b","o:","\u254","p","\u251\u342:","r","s","\u283","t")
 ),
 data.frame(stringsAsFactors=F,
   DISC=c("u" ,"U",    "v","W", "x","X",     "y", "Y",    "z","Z"    ),
   IPA= c("u:","\u28a","v","ai","x","\u254y","y:","\u28f","z","\u292")
 )
)
GIPA$IPA<-sub(":","\u2d0",GIPA$IPA)
rownames(GMFirstTable)<-sub("GFirst","",rownames(GMFirstTable))
rownames(GMLastTable)<-sub("GLast","",rownames(GMLastTable))

ST5Controls<-merge(all=T,by.x=0,by.y="Row.names",
    round(GMTable$controls[,-2],3),
  merge(all=T,by=0,suffixes=c("FirstP","LastP"),
    round(GMFirstTable[1:5,-2],3),round(GMLastTable[1:5,-2],3))
)
rownames(ST5Controls)<-ST4Controls$Row.names
ST5Controls<-ST5Controls[,-1]
ST5Phonemes<-merge(all=T,by.x=0,by.y="Row.names",
    round(GMTable$phonemes[,-2],3),
  merge(all=T,by=0,suffixes=c("FirstP","LastP"),
    round(GMFirstTable[-(1:5),-2],3),round(GMLastTable[-(1:5),-2],3))
)

rownames(ST5Phonemes)<-ST5Phonemes$Row.names
ST5Phonemes<-ST5Phonemes[,-1]
rownames(ST5Phonemes)<-GIPA$IPA[match(rownames(ST5Phonemes),GIPA$DISC)]

rownames(GMFirstTable)[!is.na(match(rownames(GMFirstTable),GIPA$DICS))]<-
  GIPA$IPA[match(rownames(GMFirstTable),GIPA$DICS)][!is.na(match(rownames(GMFirstTable),GIPA$DICS))]
rownames(GMLastTable)[!is.na(match(rownames(GMLastTable),GIPA$DICS))]<-
  GIPA$IPA[match(rownames(GMLastTable),GIPA$DICS)][!is.na(match(rownames(GMLastTable),GIPA$DICS))]
rownames(GMTable$phonemes)<-GIPA$IPA[match(rownames(GMTable),GIPA$DISC)]

GComboTable$Phoneme<-sub("GFirst","",GComboTable$Phoneme)
GComboTable$Phoneme<-GIPA$IPA[match(GComboTable$Phoneme,GIPA$DISC)]

# POLISH

Rie<-GET("https://static-content.springer.com/esm/art%3A10.3758%2Fs13428-014-0552-1/MediaObjects/13428_2014_552_MOESM1_ESM.xlsx")
writeBin(content(Rie,"raw"),"Riegel.xlsx")
rm("Rie")
Paff<-read.xlsx("Riegel.xlsx",1)
colnames(Paff)[9]<-"Valence"
colnames(Paff)[15]<-"Arousal"
gpcer_single<-function(orth,g,p,loc=1){ 
  if(loc>nchar(orth)) return(NULL);
  sorth<-substr(orth,loc,nchar(orth))
  for(i in 1:length(g)) {
    if(regexpr(paste("^",sep="",g[i]),sorth)!=-1) {
      if(nchar(g[i])>1&&substr(g[i],nchar(g[i]),nchar(g[i]))=="i"
         &&
         !substr(orth,loc+nchar(g[i])-1,loc+nchar(g[i]))%in%Pvowels){
        return(c(p[i],gpcer_single(orth,g,p,loc+nchar(g[i])-1)));
      } else {
        return(c(p[i],gpcer_single(orth,g,p,loc+nchar(g[i]))));
      }
    }
  };
 return(c("?",gpcer_single(orth,g,p,loc+1)));
}
Paff$NAWL_word<-tolower(Paff$NAWL_word)
gpcer<-Vectorize(gpcer_single,vectorize.args="orth")

Pvowels<-c("a","e","i","o","u","I","on","en")
Pphonemes  <-c("a","b","ts","d","e","f","g","x","i","j","k","l","w","m","n","o","p","r","s","t","u","v","I","z","tsi","on","ni","en","Z","si","dz","dzi","zi","S","tS","dZ")
Pdevoice_tb<-c("a","p","ts","t","e","f","k","x","i","j","k","l","f","m","n","o","p","r","s","t","u","v","I","s","tsi","on","ni","en","S","si","ts","tsi","si","S","tS","tS")
Pvoice_tb  <-c("a","b","ts","d","e","f","g","x","i","j","g","l","w","m","n","o","p","r","s","t","u","v","I","z","tsi","on","ni","en","Z","zi","dz","dzi","zi","S","dZ","dZ")
Pvoicers   <-c("b","d","g","w","z","zi","dz","dzi","dZ")
Pdevoicers <-c("p","t","k","f","s","si","ts","tsi","S","tS")

phonotactic_cluster<-function(inp){
  n<-length(inp)

  if(inp[n]%in%Pvoicers) {
      return(voice(inp))
  } else if(inp[n]%in%Pdevoicers) {
      return(devoice(inp))
  } else if(n==1) {
      return(inp)
  } else {
      return(c(phonotactic_cluster(inp[-n]),inp[n]))
  }
}

devoice_1<-function(ph)
{
  Pdevoice_tb[Pphonemes==ph]
}

devoice<-Vectorize(devoice_1)

voice_1<-function(ph)
{
  Pvoice_tb[Pphonemes==ph]
}

voice<-Vectorize(voice_1)

phonotactic_single<-function(inp,loc=1,sp=1){
  #print(c(inp,loc,sp))
  if(inp[loc]=="i"&&inp[loc+1]%in%Pvowels)
  {
    inp[loc]<-"j"
  }
  if(inp[loc]%in%Pvowels) {
    if(sp==loc) { 
      return(c(inp[loc],
             phonotactic_single(inp,loc+1,loc+1)
            )
          )
    } else {
      return(c(phonotactic_cluster(inp[sp:(loc-1)]),
             inp[loc],
             phonotactic_single(inp,loc+1,loc+1)
            )
          )
    } 
  }
  else if(loc==length(inp)) {
    return(devoice(inp[sp:loc]))
  } else if(loc>length(inp)){
    return(NULL) 
  } else
  return(phonotactic_single(inp,loc+1,sp))
}
phonotactic<-Vectorize(phonotactic_single,vectorize.args="inp")


POrth<-c("dzi","ni","rz","si","sz","cz","ci", "dz","ch","d\u17c","d\u17a","zi")
PPhon<-c("dzi","ni","Z", "si","S", "tS","tsi","dz","x", "dZ",    "dzi"   ,"zi")
POrth<-c(POrth,"a","b","c", "d","e","f","g","h","i","j","k","l","\u142","m")
PPhon<-c(PPhon,"a","b","ts","d","e","f","g","x","i","j","k","l","w"    ,"m")
POrth<-c(POrth,"n","o","p","r","s","t","u","w","y","z","\u107","\u105","\u104")
PPhon<-c(PPhon,"n","o","p","r","s","t","u","v","I","z","tsi",  "on",   "ni"   )
POrth<-c(POrth,"\u119","\u17c","\uf3","\u15b","\u144","\u17a")
PPhon<-c(PPhon,"en",   "Z",    "u",   "si",   "ni",   "dzi"  )
Ppron<-gpcer(Paff$NAWL_word,POrth,PPhon)
Ppron<-phonotactic(Ppron)

Ppron<-data.frame(Word=Paff$NAWL_word,as.data.frame(t(sapply(Ppron,function(x) c(x,rep(NA,16-length(x)))))))
colnames(Paff)[3]<-"Word"
colnames(Ppron)<-c("Word",paste("P",1:16,sep=""))
Pmain<-merge(Paff,Ppron)
Pmain[is.na(Pmain$"SUBTLEX-PL_freq"),]$"SUBTLEX-PL_freq"<-0
Pmain[is.na(Pmain$"SUBTLEX-PL_cd"),]$"SUBTLEX-PL_cd"<-0
Pmain$"SUBTLEX-PL_cd"<-as.numeric(Pmain$"SUBTLEX-PL_cd")
Pmain$LgWF<-log10(1+Pmain$"SUBTLEX-PL_freq")
Pmain$LgCD<-log10(1+Pmain$"SUBTLEX-PL_cd")
Pphonemes<-names(table(unlist(Pmain[,32:47])))
PFirst<-Pmain$P1
PLast<-apply(Pmain[,32:47],1,function(x) {r<-rev(x[!is.na(x)]); c(r,rep(NA,16-length(r)))})[1,]
Pcounts<-t(apply(Pmain[,32:47],1,function(x) table(factor(x,levels=Pphonemes))))

Pconsonants<-c("b","d","dz","dZ","dzi","f","g","j","k","l","m","n","ni","p",
               "r","s","S","si","t","ts","tS","tsi","v","w","x","z","Z",
               "zi")

Pmain$Nphonemes<-apply(Pcounts,1,sum)
Pmain$Ncons<-apply(data.frame(Pcounts)[Pconsonants],1,sum)
Pmain$Nvows<-Pmain$Nphonemes-Pmain$Ncons
Pmain$Length<-nchar(Pmain$Word)

PMControlForWhole<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal,Pmain)
PMWhole<-lm(Valence~Length+LgWF+LgCD+Arousal+Pcounts,Pmain) # NVows, NCons are redundant with Ecounts
PMTable<-create_contrast_coefs(Pmain,Pcounts)

PPF<-data.frame(front=apply(as.data.frame(Pcounts)[c("i","en","e")],1,sum))
PPF$central<-apply(as.data.frame(Pcounts)[c("I","a")],1,sum)
PPF$back<-apply(as.data.frame(Pcounts)[c("u","on","o")],1,sum)
PPF$close<-apply(as.data.frame(Pcounts)[c("i","I","u")],1,sum)
PPF$mid<-apply(as.data.frame(Pcounts)[c("en","on")],1,sum)
PPF$open<-apply(as.data.frame(Pcounts)[c("e","a","o")],1,sum)
PPF$rounded<-apply(as.data.frame(Pcounts)[c("u","on","o")],1,sum)
PPF$unrounded<-apply(as.data.frame(Pcounts)[c("i","I","en","e","a")],1,sum)
PPF$labial<-apply(as.data.frame(Pcounts)[c("m","p","b","f","v")],1,sum)
PPF$dental<-apply(as.data.frame(Pcounts)[c("n","t","d","ts","dz","s","z")],1,sum)
PPF$alveolar<-apply(as.data.frame(Pcounts)[c("r","l")],1,sum)
PPF$retroflex<-apply(as.data.frame(Pcounts)[c("tS","dzi","S","Z")],1,sum)
PPF$palatal<-apply(as.data.frame(Pcounts)[c("ni","tsi","dZ","si","zi","j")],1,sum)
PPF$velar<-apply(as.data.frame(Pcounts)[c("k","g","x","w")],1,sum)
PPF$nasal<-apply(as.data.frame(Pcounts)[c("m","n","ni")],1,sum)
PPF$plosive<-apply(as.data.frame(Pcounts)[c("p","t","k","b","d","g")],1,sum)
PPF$affricate<-apply(as.data.frame(Pcounts)[c("ts","tS","tsi","dzi","dz","dZ")],1,sum)
PPF$fricative<-apply(as.data.frame(Pcounts)[c("f","s","S","si","x","v","z","zi","Z")],1,sum)
PPF$liquid<-apply(as.data.frame(Pcounts)[c("r")],1,sum)
PPF$approximant<-apply(as.data.frame(Pcounts)[c("l","j","w")],1,sum)
PPF$voiced<-apply(as.data.frame(Pcounts)[c("m","n","ni","b","d","g","dZ","dzi","dz","v","z","zi","Z","r")],1,sum)
PPF$voiceless<-apply(as.data.frame(Pcounts)[c("p","t","k","tsi","ts","tS","f","s","S","si","x","w","l","j")],1,sum)

PMPhonetic<-lm(Valence~Length+LgWF+LgCD+Arousal+as.matrix(PPF),Pmain)

PMFirst<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+PFirst,Pmain)
PMLast<-lm(Valence~Length+Nvows+Ncons+LgWF+LgCD+Arousal+PLast,Pmain)
PMFirstTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+PFirst,Pmain))[[4]]
PMLastTable<-summary(lm(cent(Valence)~0+
                         cent(Length)+cent(Nvows)+cent(Ncons)+cent(LgWF)+
                         cent(LgCD)+cent(Arousal)+PLast,Pmain))[[4]]

PIPA<-rbind(
 data.frame(stringsAsFactors=F,
     Orth=c("S",    "Z",    "ts",     "tS",         "zi",   "ni"),
     IPA= c("\u282","\u292","t\u361s","t\u361\u282","\u291","\u272")
   ),
 data.frame(stringsAsFactors=F,
     Orth=c("dzi",        "dz",      "si",   "tsi",         "dZ"),
     IPA= c("d\u361\u291","d\u0361z","\u255","t\u0361\u255","d\u361\u290")
   ),
 data.frame(stringsAsFactors=F,
     Orth=c("on",	       "a","b","d","e",    "en",        "f","g","i"),
     IPA =c("\u254\u342","a","b","d","\u25b","\u25b\u342","f","g","i")
   ),
 data.frame(stringsAsFactors=F,
     Orth=c("I",    "j","k","l","m","n","o","p","r","s","t","u","v","w","x","z"),
     IPA =c("\u26a","j","k","l","m","n","o","p","r","s","t","u","v","w","x","z")
   )
)
PIPA$IPA<-sub(":","\u2d0",PIPA$IPA)
rownames(PMFirstTable)<-sub("PFirst","",rownames(PMFirstTable))
rownames(PMLastTable)<-sub("PLast","",rownames(PMLastTable))

ST6Controls<-merge(all=T,by.x=0,by.y="Row.names",
    round(PMTable$controls[,-2],3),
  merge(all=T,by=0,suffixes=c("FirstP","LastP"),
    round(PMFirstTable[1:6,-2],3),round(PMLastTable[1:6,-2],3))
)
rownames(ST6Controls)<-ST6Controls$Row.names
ST6Controls<-ST6Controls[,-1]
ST6Phonemes<-merge(all=T,by.x=0,by.y="Row.names",
    round(PMTable$phonemes[,-2],3),
  merge(all=T,by=0,suffixes=c("FirstP","LastP"),
    round(PMFirstTable[-(1:6),-2],3),round(PMLastTable[-(1:6),-2],3))
)

rownames(ST6Phonemes)<-ST6Phonemes$Row.names
ST6Phonemes<-ST6Phonemes[,-1]
rownames(ST6Phonemes)<-PIPA$IPA[match(rownames(ST6Phonemes),PIPA$Orth)]

rownames(PMFirstTable)[!is.na(match(rownames(PMFirstTable),PIPA$Orth))]<-
  PIPA$IPA[match(rownames(PMFirstTable),PIPA$Orth)][!is.na(match(rownames(PMFirstTable),PIPA$Orth))]
rownames(PMLastTable)[!is.na(match(rownames(PMLastTable),PIPA$Orth))]<-
  PIPA$IPA[match(rownames(PMLastTable),PIPA$Orth)][!is.na(match(rownames(PMLastTable),PIPA$Orth))]
rownames(PMTable$phonemes)<-PIPA$IPA[match(rownames(PMTable),PIPA$Orth)]

#### Here we go
outfile<-file("output.txt",open="w")
sink(outfile)
cat('\xEF\xBB\xBF')

Languages<-c("English","Spanish","Dutch","German","Polish")

cat("[p.6] Numbers of valid words, TOTAL\r\r\n")

print.table(c(English=dim(Emain)[1],
              Spanish=dim(Smain)[1],
              Dutch  =dim(Dmain)[1],
              German =dim(Gmain)[1],
              Polish =dim(Pmain)[1]
          )
)

cat("[p.7] Method: ENGLISH\r\n\r\n")

print.table(c(WarrinerEtAl=dim(Eaff)[1],FinalList=dim(Emain)[1],
              Omitted=dim(Eaff)[1]-dim(Emain)[1],
              NPhonemes=length(Ephonemes),AdelmanEtAl=dim(E2aff)[1],
              NLatencies=sum(!is.na(Emain$RT))))

cat("\r\n[p.8] Method: ENGLISH cont'd\r\n\r\n")

print.table(c(ReplicationN=dim(E2main)[1],RepOmitted=dim(E2aff)[1]-dim(E2main)[1]))

cat("\r\n[p.8] Method: SPANISH\r\n\r\n")

print.table(c(Stadthagen=dim(Saff)[1],FinalList=dim(Smain)[1],
              Omitted=dim(Saff)[1]-dim(Smain)[1],
              NPhonemes=length(Sphonemes)))

cat("\r\n[p.8] Method: DUTCH\r\n\r\n")

print.table(c(Moors=dim(Daff)[1],FinalList=dim(Dmain)[1],
              Omitted=dim(Daff)[1]-dim(Dmain)[1],
              NPhonemes=length(Dphonemes)))

cat("\r\n[p.8] Method: GERMAN\r\n\r\n")

print.table(c(Vo=dim(Gaff)[1],FinalList=dim(Gmain)[1],
              Omitted=dim(Gaff)[1]-dim(Gmain)[1],
              NPhonemes=length(Gphonemes),
              NLatencies=sum(!is.na(Gmain$RT))))

cat("\r\n[p.8] Method: POLISH\r\n\r\n")

print.table(c(Riegel=dim(Paff)[1]))

cat("\r\n[p.9] Method: POLISH cont'd\r\n\r\n")

print.table(c(FinalList=dim(Pmain)[1],
              Omitted=dim(Paff)[1]-dim(Pmain)[1],
              NPhonemes=length(Pphonemes)))

cat("\r\n[p.9] Method: Analyses\r\n\r\n")

print.table(c(Phonemes=length(Ephonemes),Words=dim(Emain)[1]))

cat("\r\n[p.10] Method: Analyses cont'd\r\n\r\n")

print.table(c(GermanPhonemes=length(Gphonemes),ExptdError=.05*length(Gphonemes)))

cat("\r\n[p.11] Results: Emotional sound symbolism\r\n\r\n")

cat("ENGLISH\r\n")
print.table(signif(c(
"deltaRSquared (%)"=100*
  (summary(EMWhole)$r.squared-summary(EMControlForWhole)$r.squared),
p=anova(EMControlForWhole,EMWhole)[[6]][2],
"No. of sig. phonemes (%)"=100*mean(EMTable$phonemes[,4]<.05),
"LengthEffect (%)"=100*
  (summary(EMWhole)$r.squared-summary(EMWholeLessLength)$r.squared)
),3))

print.table(signif(c(
"Split-half average R"=mean(splithalves),
N=length(splithalves),
"Reliability"=2*mean(splithalves)/(1+mean(splithalves))
),3))

cat("\r\n[p.12] Results: Emotional sound symbolism cont'd\r\n\r\n")

cat("ENGLISH cont'd\r\n")

print.table(round(c("Monomorph N"=sum(EmonoL,na.rm=T),
                 "Delta R-squared (%)"=100*
                   (summary(EMMonoWhole)$r.squared
                   -summary(EMMonoControlForWhole)$r.squared)
                      ),2)
)
print.table(signif(c(p=anova(EMMonoControlForWhole,EMMonoWhole)[[6]][2]),3))

cat("\r\n")

print.table(round(c("Replication N"=dim(E2main)[1],
  "Delta R-squared (%)"=100*
                   (summary(E2MWhole)$r.squared
                   -summary(E2MControlForWhole)$r.squared)
                      ),2)
)
print.table(signif(c(p=anova(E2MControlForWhole,E2MWhole)[[6]][2]),3))

print.table(c(
  "Inter-rater N"=sum(EcommonL)))
print.table(c(
  "Inter-rater r"=cor(EcommonTable$phonemes[,1],E2commonTable$phonemes[,1]),
  p=cor.test(EcommonTable$phonemes[,1],E2commonTable$phonemes[,1])$p.value
))

cat("\r\n[p.12] Results: NON-ENGLISH\r\n\r\n")

print(data.frame(check.names=F,
  row.names=Languages[-1],
  "Delta R-squared (%)"=100*
    c(
      summary(SMWhole)$r.squared
      -summary(SMControlForWhole)$r.squared,
      summary(DMWhole)$r.squared
      -summary(DMControlForWhole)$r.squared,
      summary(GMWhole)$r.squared
      -summary(GMControlForWhole)$r.squared,
      summary(PMWhole)$r.squared
      -summary(PMControlForWhole)$r.squared
     ),
  p=c(
      anova(SMControlForWhole,SMWhole)[[6]][2],
      anova(DMControlForWhole,DMWhole)[[6]][2],
      anova(GMControlForWhole,GMWhole)[[6]][2],
      anova(PMControlForWhole,PMWhole)[[6]][2]
  ),
  "No. of sig. phonemes (%)"=
      c(
        100*mean(SMTable$phonemes[,4]<.05),
        100*mean(DMTable$phonemes[,4]<.05),
        100*mean(GMTable$phonemes[,4]<.05),
        100*mean(PMTable$phonemes[,4]<.05)
        )
  )
)

cat("\r\n[p.12] Results: (Typical) Phonetic Features\r\n\r\n")

print(data.frame(check.names=F,
  row.names=Languages,
  "Delta R-squared Phonetic (%)"=100*
    c(
      summary(EMPhonetic)$r.squared
      -summary(EMControlForWhole)$r.squared,
      summary(SMPhonetic)$r.squared
      -summary(SMControlForWhole)$r.squared,
      summary(DMPhonetic)$r.squared
      -summary(DMControlForWhole)$r.squared,
      summary(GMPhonetic)$r.squared
      -summary(GMControlForWhole)$r.squared,
      summary(PMPhonetic)$r.squared
      -summary(PMControlForWhole)$r.squared
     ),
  p=c(
      anova(EMControlForWhole,EMPhonetic)[[6]][2],
      anova(SMControlForWhole,SMPhonetic)[[6]][2],
      anova(DMControlForWhole,DMPhonetic)[[6]][2],
      anova(GMControlForWhole,GMPhonetic)[[6]][2],
      anova(PMControlForWhole,PMPhonetic)[[6]][2]
  )
))

cat("\r\n[p.13] Results: Phonemes vs. (Typical) Phonetic Features\r\n\r\n")

print(data.frame(check.names=F,
  row.names=Languages,
  "Delta R-squared Phonemic>Phonetic (%)"=100*
    c(
      summary(EMWhole)$r.squared
      -summary(EMPhonetic)$r.squared,
      summary(SMWhole)$r.squared
      -summary(SMPhonetic)$r.squared,
      summary(DMWhole)$r.squared
      -summary(DMPhonetic)$r.squared,
      summary(GMWhole)$r.squared
      -summary(GMPhonetic)$r.squared,
      summary(PMWhole)$r.squared
      -summary(PMPhonetic)$r.squared
     ),
  p=c(
      anova(EMPhonetic,EMWhole)[[6]][2],
      anova(SMPhonetic,SMWhole)[[6]][2],
      anova(DMPhonetic,DMWhole)[[6]][2],
      anova(GMPhonetic,GMWhole)[[6]][2],
      anova(PMPhonetic,PMWhole)[[6]][2]
  )
))

cat("\r\n[p.13] Results: Front-loading, first vs. last\r\n\r\n")

print(data.frame(check.names=F,
  row.names=Languages,
  "Delta R-squared First (%)"=100*
    c(
      summary(EMFirst)$r.squared
      -summary(EMControlForWhole)$r.squared,
      summary(SMFirst)$r.squared
      -summary(SMControlForWhole)$r.squared,
      summary(DMFirst)$r.squared
      -summary(DMControlForWhole)$r.squared,
      summary(GMFirst)$r.squared
      -summary(GMControlForWhole)$r.squared,
      summary(PMFirst)$r.squared
      -summary(PMControlForWhole)$r.squared
     ),
  p=c(
      anova(EMControlForWhole,EMFirst)[[6]][2],
      anova(SMControlForWhole,SMFirst)[[6]][2],
      anova(DMControlForWhole,DMFirst)[[6]][2],
      anova(GMControlForWhole,GMFirst)[[6]][2],
      anova(PMControlForWhole,PMFirst)[[6]][2]
  ),
  "Delta R-squared Last (%)"=100*
    c(
      summary(EMLast)$r.squared
      -summary(EMControlForWhole)$r.squared,
      summary(SMLast)$r.squared
      -summary(SMControlForWhole)$r.squared,
      summary(DMLast)$r.squared
      -summary(DMControlForWhole)$r.squared,
      summary(GMLast)$r.squared
      -summary(GMControlForWhole)$r.squared,
      summary(PMLast)$r.squared
      -summary(PMControlForWhole)$r.squared
     ),
  p=c(
      anova(EMControlForWhole,EMLast)[[6]][2],
      anova(SMControlForWhole,SMLast)[[6]][2],
      anova(DMControlForWhole,DMLast)[[6]][2],
      anova(GMControlForWhole,GMLast)[[6]][2],
      anova(PMControlForWhole,PMLast)[[6]][2]
  )
))

cat("\r\n[p.13] Results: Front-loading, first 5 phonemes\r\n\r\n")

print(data.frame(row.names=c("English","Spanish"),N=c(sum(ElongL),sum(SlongL))))

cat("\r\n[p.14] Results: Front-loading, first 5 phonemes cont'd\r\n\r\n")

print(data.frame(check.names=F,
      "English Delta-R-squared (%)"=
       100*(
        c(
            summary(EMP1)$r.squared,
            summary(EMP2)$r.squared,
            summary(EMP3)$r.squared,
            summary(EMP4)$r.squared,
            summary(EMP5)$r.squared
          )      
          -summary(EMControlForPositions)$r.squared
        ),
      "p"=c(
        anova(EMControlForPositions,EMP1)[[6]][2],
        anova(EMControlForPositions,EMP2)[[6]][2],
        anova(EMControlForPositions,EMP3)[[6]][2],
        anova(EMControlForPositions,EMP4)[[6]][2],
        anova(EMControlForPositions,EMP5)[[6]][2]
      ),
      "Spanish Delta-R-squared (%)"=
       100*(
        c(
            summary(SMP1)$r.squared,
            summary(SMP2)$r.squared,
            summary(SMP3)$r.squared,
            summary(SMP4)$r.squared,
            summary(SMP5)$r.squared
          )      
          -summary(SMControlForPositions)$r.squared
        ),
      "p"=c(
        anova(SMControlForPositions,SMP1)[[6]][2],
        anova(SMControlForPositions,SMP2)[[6]][2],
        anova(SMControlForPositions,SMP3)[[6]][2],
        anova(SMControlForPositions,SMP4)[[6]][2],
        anova(SMControlForPositions,SMP5)[[6]][2]
      )
))

cat("\r\n[p.14] Results: Back-loading of frequency\r\n\r\n")

print(data.frame(check.names=F,
      row.names=c("First","Last"),
      "English Delta-R-squared (%)"=
       100*(
        c(
            summary(EFMFirst)$r.squared,
            summary(EFMLast)$r.squared
          )      
          -summary(EFMControl)$r.squared
        ),
      "p"=c(
        anova(EFMControl,EFMFirst)[[6]][2],
        anova(EFMControl,EFMLast)[[6]][2]
      ),
      "Spanish Delta-R-squared (%)"=
       100*(
        c(
            summary(SFMFirst)$r.squared,
            summary(SFMLast)$r.squared
          )      
          -summary(SFMControl)$r.squared
        ),
      "p"=c(
        anova(SFMControl,SFMFirst)[[6]][2],
        anova(SFMControl,SFMLast)[[6]][2]
      )
))


cat("\r\n[p.15] Results: Negative priority\r\n\r\n")

print(data.frame(
 row.names=c("English","German"),
 "R-squared"=
       100*(
        c(
            summary(EMRT)$r.squared,
            summary(GMRT)$r.squared
          )      
        ),
      "p"=c(
        1-pf(EMRTF[1],EMRTF[2],EMRTF[3]),
        1-pf(GMRTF[1],GMRTF[2],GMRTF[3])
      )
))

print(
 data.frame(
  row.names=c(
   "English (ELP naming onset)",
   "English (ELP naming onset, no ZH)",
   "German (DeveL young adult naming onset)",
   "English (Offset data)"
  ),
  N=c(
   dim(EComboTable)[1],
   dim(EComboTableNoZH)[1],
   dim(GComboTable)[1],
   dim(EOffsetComboTable)[1]
  ),
  r=c(
   cor(EComboTable[,2],EComboTable[,3]),
   cor(EComboTableNoZH[,2],EComboTableNoZH[,3]),
   cor(GComboTable[,2],GComboTable[,3]),
   with(EOffsetComboTable,cor(Offset,y))
  ),
  p=c(
   cor.test(EComboTable[,2],EComboTable[,3])$p.value,
   cor.test(EComboTableNoZH[,2],EComboTableNoZH[,3])$p.value,
   cor.test(GComboTable[,2],GComboTable[,3])$p.value,
   with(EOffsetComboTable,cor.test(Offset,y))$p.value
  )
 )
)

cat("\r\n[p.29] Table 1\r\n\r\n")

sink()
close(outfile)
outfile<-file("output.txt",open="ab")
writeUtf8(tableToText(EMFirstTable[-(1:6),-2]),outfile,bom=F)
writeUtf8(tableToCsv(EMFirstTable[-(1:6),-2]),"Table1.csv",bom=T)

sink(outfile)
cat("\r\n[p.30] Figure 1 English\r\n\r\n")
sink()
writeUtf8(tableToText(data.frame(
  row.names=rownames(EMTable$phonemes),
  Valence=EMTable$phonemes[,1],
  Precision=1/EMTable$phonemes[,2]
  )),outfile,bom=F
)
sink(outfile)
cat("\r\n[p.30] Figure 1 Spanish\r\n\r\n")
sink()
writeUtf8(tableToText(data.frame(
  row.names=rownames(SMTable$phonemes),
  Valence=SMTable$phonemes[,1],
  Precision=1/SMTable$phonemes[,2]
  )),outfile,bom=F
)

F1Data<-rbind(
    data.frame(Language=ordered("English",levels=c("English","Spanish")),
      Phoneme=rownames(EMTable$phonemes),
      Valence=EMTable$phonemes[,1],
      Precision=1/EMTable$phonemes[,2]
    ),
    data.frame(Language=ordered("Spanish",levels=c("English","Spanish")),
      Phoneme=rownames(SMTable$phonemes),
      Valence=SMTable$phonemes[,1],
      Precision=1/SMTable$phonemes[,2]
    )
  )
close(outfile)
outfile<-file("output.txt",open="a")
sink(outfile)
cat("\r\n[p.31] Figure 2\r\n\r\n")
print(data.frame(check.names=F,
  row.names=Languages,
  "Delta R-squared Phonetic (%)"=100*
    c(
      summary(EMPhonetic)$r.squared
      -summary(EMControlForWhole)$r.squared,
      summary(SMPhonetic)$r.squared
      -summary(SMControlForWhole)$r.squared,
      summary(DMPhonetic)$r.squared
      -summary(DMControlForWhole)$r.squared,
      summary(GMPhonetic)$r.squared
      -summary(GMControlForWhole)$r.squared,
      summary(PMPhonetic)$r.squared
      -summary(PMControlForWhole)$r.squared
     ),
  "Delta R-squared Phonemic(%)"=100*
    c(
      summary(EMWhole)$r.squared
      -summary(EMControlForWhole)$r.squared,
      summary(SMWhole)$r.squared
      -summary(SMControlForWhole)$r.squared,
      summary(DMWhole)$r.squared
      -summary(DMControlForWhole)$r.squared,
      summary(GMWhole)$r.squared
      -summary(GMControlForWhole)$r.squared,
      summary(PMWhole)$r.squared
      -summary(PMControlForWhole)$r.squared
     )
))

cat("\r\n[p.32] Figure 3A\r\n\r\n")
print(data.frame(check.names=F,
  row.names=Languages,
  "Delta R-squared First (%)"=100*
    c(
      summary(EMFirst)$r.squared
      -summary(EMControlForWhole)$r.squared,
      summary(SMFirst)$r.squared
      -summary(SMControlForWhole)$r.squared,
      summary(DMFirst)$r.squared
      -summary(DMControlForWhole)$r.squared,
      summary(GMFirst)$r.squared
      -summary(GMControlForWhole)$r.squared,
      summary(PMFirst)$r.squared
      -summary(PMControlForWhole)$r.squared
     ),
  "Delta R-squared Last (%)"=100*
    c(
      summary(EMLast)$r.squared
      -summary(EMControlForWhole)$r.squared,
      summary(SMLast)$r.squared
      -summary(SMControlForWhole)$r.squared,
      summary(DMLast)$r.squared
      -summary(DMControlForWhole)$r.squared,
      summary(GMLast)$r.squared
      -summary(GMControlForWhole)$r.squared,
      summary(PMLast)$r.squared
      -summary(PMControlForWhole)$r.squared
     )
))

cat("\r\n[p.32] Figure 3B\r\n\r\n")

print(data.frame(check.names=F,
      "English Delta-R-squared (%)"=
       100*(
        c(
            summary(EMP1)$r.squared,
            summary(EMP2)$r.squared,
            summary(EMP3)$r.squared,
            summary(EMP4)$r.squared,
            summary(EMP5)$r.squared
          )      
          -summary(EMControlForPositions)$r.squared
        ),
      "Spanish Delta-R-squared (%)"=
       100*(
        c(
            summary(SMP1)$r.squared,
            summary(SMP2)$r.squared,
            summary(SMP3)$r.squared,
            summary(SMP4)$r.squared,
            summary(SMP5)$r.squared
          )      
          -summary(SMControlForPositions)$r.squared
        )
))

cat("\r\n[p.33] Figure 4 Caption\r\n\r\n")

print(
 data.frame(check.names=F,
  row.names=c(
   "English (ELP naming onset)",
   "English (ELP naming onset, no ZH)",
   "German (DeveL young adult naming onset)"
  ),
  r=c(
   cor(EComboTable[,2],EComboTable[,3]),
   cor(EComboTableNoZH[,2],EComboTableNoZH[,3]),
   cor(GComboTable[,2],GComboTable[,3])
  )
 )
)

cat("\r\n[p.33] Figure 4 English\r\n\r\n")
sink()
close(outfile)
outfile<-file("output.txt",open="ab")
writeUtf8(tableToText(EComboTableNoZH),outfile,bom=F)
writeUtf8(tableToCsv(EComboTableNoZH),"Figure4E.csv",bom=T)

sink(outfile)
cat("\r\n[p.33] Figure 4 German\r\n\r\n")
sink()
writeUtf8(tableToText(GComboTable),outfile,bom=F)
writeUtf8(tableToCsv(GComboTable),"Figure4G.csv",bom=T)

close(outfile)
outfile<-file("output.txt",open="a")
sink(outfile)
cat("\r\n[p.34] S Table 1\r\n\r\n")

print(data.frame(check.names=F,
  row.names=c("AllW","MonoW"),
  "Control Block R-sq (%)"=100*c(
    summary(EMControlForWhole)$r.squared,
    summary(EMMonoControlForWhole)$r.squared
  )
))

sink()
close(outfile)
outfile<-file("output.txt",open="ab")

writeUtf8(tableToText(ST1Controls),outfile,bom=F)
writeUtf8(tableToText(ST1Phonemes),outfile,bom=F)
writeUtf8(tableToCsv(ST1Controls),"ST1.csv",bom=T)
writeUtf8(tableToCsv(ST1Phonemes),"ST1.csv",open="ab",bom=F)

close(outfile)
outfile<-file("output.txt",open="a")
sink(outfile)
cat("\r\n[p.35] S Table 2\r\n\r\n")

print(data.frame(check.names=F,
  row.names=c("Adel","Common-Adel","Common-Warr"),
  "Control Block R-sq (%)"=100*c(
    summary(E2MControlForWhole)$r.squared,
    summary(E2McommonControl)$r.squared,
    summary(EMcommonControl)$r.squared
  ),
  "Phoneme Block R-sq (%)"=100*c(
    summary(E2MWhole)$r.squared-summary(E2MControlForWhole)$r.squared,
    summary(E2Mcommon)$r.squared-summary(E2McommonControl)$r.squared,
    summary(EMcommon)$r.squared-summary(EMcommonControl)$r.squared
  ),
  p=c(
    anova(E2MControlForWhole,E2MWhole)[[6]][2],
    anova(E2McommonControl,E2Mcommon)[[6]][2],
    anova(EMcommonControl,EMcommon)[[6]][2]
  )
))

sink()
close(outfile)
outfile<-file("output.txt",open="ab")

writeUtf8(tableToText(ST2Controls),outfile,bom=F)
writeUtf8(tableToText(ST2Phonemes),outfile,bom=F)
writeUtf8(tableToCsv(ST2Controls),"ST2.csv",bom=T)
writeUtf8(tableToCsv(ST2Phonemes),"ST2.csv",open="ab",bom=F)

close(outfile)
outfile<-file("output.txt",open="a")
sink(outfile)
cat("\r\n[p.36] S Table 3\r\n\r\n")

print.table(c(
  "Control Block R-sq (%)"=100*
    summary(SMControlForWhole)$r.squared
))

sink()
close(outfile)
outfile<-file("output.txt",open="ab")
writeUtf8(tableToText(ST3Controls),outfile,bom=F)
writeUtf8(tableToText(ST3Phonemes),outfile,bom=F)
writeUtf8(tableToCsv(ST3Controls),"ST3.csv",bom=T)
writeUtf8(tableToCsv(ST3Phonemes),"ST3.csv",open="ab",bom=F)

close(outfile)
outfile<-file("output.txt",open="a")
sink(outfile)
cat("\r\n[p.37] S Table 4\r\n\r\n")

print.table(c(
  "Control Block R-sq (%)"=100*
    summary(DMControlForWhole)$r.squared
))

sink()
close(outfile)
outfile<-file("output.txt",open="ab")
writeUtf8(tableToText(ST4Controls),outfile,bom=F)
writeUtf8(tableToText(ST4Phonemes),outfile,bom=F)
writeUtf8(tableToCsv(ST4Controls),"ST4.csv",bom=T)
writeUtf8(tableToCsv(ST4Phonemes),"ST4.csv",open="ab",bom=F)

close(outfile)
outfile<-file("output.txt",open="a")
sink(outfile)
cat("\r\n[p.38] S Table 5\r\n\r\n")

print.table(c(
  "Control Block R-sq (%)"=100*
    summary(GMControlForWhole)$r.squared
))

sink()
close(outfile)
outfile<-file("output.txt",open="ab")
writeUtf8(tableToText(ST5Controls),outfile,bom=F)
writeUtf8(tableToText(ST5Phonemes),outfile,bom=F)
writeUtf8(tableToCsv(ST5Controls),"ST5.csv",bom=T)
writeUtf8(tableToCsv(ST5Phonemes),"ST5.csv",open="ab",bom=F)

close(outfile)
outfile<-file("output.txt",open="a")
sink(outfile)
cat("\r\n[p.39] S Table 6\r\n\r\n")

print.table(c(
  "Control Block R-sq (%)"=100*
    summary(PMControlForWhole)$r.squared
))

sink()
close(outfile)
outfile<-file("output.txt",open="ab")
writeUtf8(tableToText(ST6Controls),outfile,bom=F)
writeUtf8(tableToText(ST6Phonemes),outfile,bom=F)
writeUtf8(tableToCsv(ST6Controls),"ST6.csv",bom=T)
writeUtf8(tableToCsv(ST6Phonemes),"ST6.csv",open="ab",bom=F)

close(outfile)
gc()
png(file="Figure1.png",width=800*4,height=600*4,res=72*4)
print(xyplot(
  Valence~Precision|Language,
  data=F1Data,
  panel=function(x,y,...) {
    d<-expand.grid(xg=0:3500/50,yg=-240:200/500);
    panel.levelplot(x=d$xg,y=d$yg,z=d$xg*d$yg,contour=F,
                    at=qnorm(c(0,.025,.05,.5,.95,.975,1)),
                    subscripts=rep(T,dim(d)[1]),
       col.regions=rev(c("#00bb00","#55ff55","#ddffdd","#ffdddd","#ff7777","#ff0000")),
    )
    panel.text(x,y,labels=F1Data$Phoneme,...)
    panel.text(c(40,40),c(-.25,.25),cex=1.5,pos=4,labels="p",fontface=4,col="white")
    panel.text(c(40,40),c(-.25,.25),cex=1.5,pos=4,labels="   < .05",fontface="bold",col="white")
    },
  xlab=list("Precision of the Valence Estimate (1/SE)",fontface="bold",cex=1.5),
  ylab=list("Valence (B)",fontface="bold",cex=1.5),
  cex=1, table=T,
  strip=strip.custom(par.strip.text=list(fontface="bold",cex=1.5)),
         par.settings = list(layout.heights=list(strip=1.65))
))
dev.off()

outfile<-file("output.txt",open="a")
sink(outfile)
cat("\r\n[p.41] Testing an Interaction Model\r\n\r\n")
print(data.frame(
 F=anova(EMINTControl,EMINTFirst)[[5]][2],
 df1=anova(EMINTControl,EMINTFirst)[[3]][2],
 df2=anova(EMINTControl,EMINTFirst)[[1]][2],
 p=anova(EMINTControl,EMINTFirst)[[6]][2]
))

print(data.frame(check.names=F,
  "Number of sig. phonemes (%)"=100*mean(EMINTTable[-(1:7),4]<.05)
))
sink()
close(outfile)


outfile<-file("output.txt",open="ab")
writeUtf8(tableToText(EMINTCompTable[-(1:6),]),outfile,bom=F)
close(outfile)
