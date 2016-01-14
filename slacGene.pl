#!/usr/bin/env perl
#
# slacGene - SVG Large Annotated Circular Gene maps
#
# Original version: 12/10/2014 John P. McCrow (jmccrow [at] jcvi.org)
# J. Craig Venter Institute (JCVI)
# La Jolla, CA USA
#

use strict;
use Math::Trig;
use Getopt::Long;

### GLOBAL ###

use constant {

    layer_bottom => 0,
    layer_gene => 1,
    layer_text => 2,
    layer_top => 3
    
};

# Init
my $basepath = $0;
$basepath =~ s/\/[^\/]+$//;

my $initfile = $basepath."/config.txt";

# Default parameters, can be changed in initfile
my %defparam = (
    'direction'=>-1, # must be -1 or 1, for clockwise or counterclockwise
    'rotation'=>0,
    'depth'=>10,
    'view_width'=>30000,
    'view_height'=>30000,
    'line_width'=>10,
    'font_size'=>300,
    'title_text'=>'',
    'font_color'=>'#000000',
    'foreground_color'=>'#000000',
    'label_color'=>'#000000',
    'font_family'=>'Verdana',
    'zoom'=>1,
    'x_offset'=>0,
    'y_offset'=>0,
    'bandwidth'=>400,
    'thin_bandwidth'=>100,
    'tic_size'=>100,
    'stack_radius'=>7
);

# Command line parameters
my $infile;
my $outfile;
my $forceoverwrite;
my $showhelp;
my $useSTDIN;

#Default Parameters
my $direction = $defparam{'direction'};
my $rotation = $defparam{'rotation'};
my $maxanndepth = $defparam{'depth'};
my $viewwidth = $defparam{'view_width'};
my $viewheight = $defparam{'view_height'};
my $linewidth = $defparam{'line_width'};
my $fontsize = $defparam{'font_size'};
my $titlestr = $defparam{'title_text'};
my $fontcolor = $defparam{'font_color'};
my $fgcolor = $defparam{'foreground_color'};
my $labelcolor = $defparam{'label_color'};
my $fontfam = $defparam{'font_family'};
my $zoom = $defparam{'zoom'};
my $xoffset = $defparam{'x_offset'};
my $yoffset = $defparam{'y_offset'};
my $bandwidth = $defparam{'bandwidth'};
my $thinbandwidth = $defparam{'thin_bandwidth'};
my $ticsize = $defparam{'tic_size'};
my $stackradius = $defparam{'stack_radius'};

my $minposnum;
my $maxposnum;
my $posrange;
my $layer;
my $maxx;
my $maxy;
my $xmult;
my $ymult;
my $rcx;
my $rcy;
my $minfont;
my $maxfont;

my %svglayerstr;
my %levlist_type;
my %levlist_val;
my %levlist_dir;
my %levlist_clr;
my %levlist_clr2;
my %levstack_clrlist;
my %all_levels;

### SUBS ###

sub checkparams() {
    my $retval = 0;
    
    if($maxposnum > 0 &&
        $maxanndepth > 0)
    {
        $retval = 1;
    }
    return $retval;
}

sub init_config {
    if(open(INIT, $initfile)) {
        while(<INIT>) {
            chomp;
            unless(/^\#/) {
                my ($key, $val) = split(/[\t\s]+/);
                if(length($key) > 0 && length($val) > 0) {
                    $defparam{$key} = $val;
                }
            }
        }
    } # ignore config file if not found
}

sub open_handles {
    if($useSTDIN) {
        open(IN, "<&=STDIN") or die "Unable to read from STDIN\n";
    } else {
        open(IN, $infile) or die "Unable to open file $infile\n";
    }
    
    if(length($outfile) > 0) {
        if(!$forceoverwrite && -e $outfile) {
            die "Output file already exists: $outfile\n(Remove file, or use -f option to force overwrite)\n";
        }
        open(OUT, ">".$outfile) or die "Unable to write to file $outfile\n";
        
    } else {
        open(OUT, ">&=STDOUT") or die "Unable to write to STDOUT\n";
    }
    
}

sub readannotations() {
    open(IN, $infile) or die "Unable to read file $infile\n";
    while(<IN>) {
        chomp;
        unless(/^\#/ || /^\s*$/) {
            my ($atype, @cols) = split(/\t/);
        
            if($atype =~ /^setscale/i) {
                my ($min, $max, $dir, $rot) = @cols;
                $minposnum = $min;
                $maxposnum = $max;
                $direction = ($dir > 0 ? 1 : -1);
                $rotation = $rot;
                
            } elsif($atype =~ /^title/i) {
                my ($txt) = @cols;
                $titlestr = $txt;
                
            } elsif($atype =~ /^level/i) {
                my ($level, $type, $clr, $clr2) = @cols;
                push(@{$levlist_type{$level}}, "level");
                push(@{$levlist_val{$level}}, $type);
                push(@{$levlist_clr{$level}}, $clr);
\                push(@{$levlist_clr2{$level}}, $clr2);
                
            } elsif($atype =~ /^drawscale/i) {
                my ($level, $tictype, $ticunit, $clr) = @cols;
                $all_levels{$level} = 1;
                push(@{$levlist_type{$level}}, "scale");
                push(@{$levlist_val{$level}}, $tictype.",".$ticunit);
                push(@{$levlist_clr{$level}}, $clr);
                
            } elsif($atype =~ /^region/i) {
                my ($s, $e, $level, $clr, $dir) = @cols;
                $maxposnum = max($maxposnum, $s, $e);
                $all_levels{$level} = 1;
                push(@{$levlist_type{$level}}, "region");
                push(@{$levlist_val{$level}}, $s.",".$e);
                push(@{$levlist_clr{$level}}, $clr);
                push(@{$levlist_dir{$level}}, $dir);
                
            } elsif($atype =~ /^line/i) {
                my ($s, $e, $level, $clr) = @cols;
                $maxposnum = max($maxposnum, $s, $e);
                $all_levels{$level} = 1;
                push(@{$levlist_type{$level}}, "line");
                push(@{$levlist_val{$level}}, $s.",".$e);
                push(@{$levlist_clr{$level}}, $clr);
                
            } elsif($atype =~ /^point/i) {
                my ($p, $level, $clr) = @cols;
                $maxposnum = max($maxposnum, $p);
                $all_levels{$level} = 1;
                push(@{$levlist_type{$level}}, "point");
                push(@{$levlist_val{$level}}, $p);
                push(@{$levlist_clr{$level}}, $clr);
                
            } elsif($atype =~ /^stack/i) {
                my ($p, $amount, $level, $clr) = @cols;
                unless(exists($levstack_clrlist{$level}{$p})) {
                    $maxposnum = max($maxposnum, $p);
                    $all_levels{$level} = 1;
                    push(@{$levlist_type{$level}}, "stack");
                    push(@{$levlist_val{$level}}, $p);
                }
                for(my $i=0; $i<$amount; $i++) { # Add each point to the stack
                    push(@{$levstack_clrlist{$level}{$p}}, $clr);
                }
                
            } elsif($atype =~ /^origin/i) {
                my ($p, $fr, $ud, $level, $clr) = @cols;
                $maxposnum = max($maxposnum, $p);
                $all_levels{$level} = 1;
                push(@{$levlist_type{$level}}, "origin");
                push(@{$levlist_val{$level}}, $p.",".$fr.",".$ud);
                push(@{$levlist_clr{$level}}, $clr);
                
            } else {
                print STDERR "Unknown annotation type: $_\n";
                
            }
        }
    }
    close(IN);

}

sub calcscaleparams() {
    #Calculate scale parameters
    $posrange = $maxposnum - $minposnum + 1;
    $maxfont = $viewheight/100;
    $minfont = $viewheight/1000;
    $xmult = ($zoom*$viewwidth*0.95)/($maxanndepth*3);
    $ymult = 360 / $posrange;
    $rcx = ($viewwidth*$xoffset) + ($viewwidth/2);
    $rcy = ($viewwidth*$yoffset) + ($viewwidth/2);
}

sub max {
    my $m = 0;
    foreach my $v (@_) {
        if($v > $m) { $m = $v; }
    }
    return $m;
}

# Naming convention for drawing subs is the following:
#    radial- convert between absolute and radial coordinates
#    print-  direct printing of absolute space objects in SVG
#    d-      lower level drawing of individual objects in tree space with conversion to absolute printing space
#    draw-   high level drawing, or other calculations, before calling d- subs

sub radialx {
    my $x = shift;
    my $y = shift;
    
    return ($rcx + sin(deg2rad($direction*$y*$ymult+$rotation))*$x);
}

sub radialy {
    my $x = shift;
    my $y = shift;
    
    return ($rcy + cos(deg2rad($direction*$y*$ymult+$rotation))*$x);
}

sub radialangle {
    my $y = shift;
    
    return (90-($direction*$y*$ymult+$rotation));
}

sub printline($$$$) {
    my ($x1, $y1, $x2, $y2) = @_;
    
    $svglayerstr{$layer} .= "\t<path fill=\"none\" stroke=\"$fgcolor\" stroke-width=\"$linewidth\" d=\"M $x1 $y1 L $x2 $y2\"/>\n";
}

sub printarc {
    my ($x1, $y1, $x2, $y2, $r, $inout) = @_;
    
    $svglayerstr{$layer} .= "\t<path fill=\"none\" stroke=\"$fgcolor\" stroke-width=\"$linewidth\" d=\"M $x1 $y1 A $r $r 0 $inout 0 $x2 $y2\"/>\n";
}

sub printbox {
    my ($x1, $y1, $x2, $y2) = @_;
    
    $svglayerstr{$layer} .= "\t<path fill=\"$fgcolor\" stroke=\"none\" stroke-width=\"0\" d=\"M $x1 $y1 L $x1 $y2 L $x2 $y2 L $x2 $y1 Z\"/>\n";
}

sub printtext {
    my ($x, $y, $str, $alignx, $aligny) = @_;
    
    my $alignxstr;
    my $alignystr;
    
    if($alignx eq "center") {
        $alignxstr = "text-anchor=\"middle\"";
    } else {
        $alignxstr = "";
    }
    
    if($aligny eq "bottom") {
        $alignystr = "";
    } else {
        $alignystr = "dominant-baseline=\"central\"";
    }
    
    $svglayerstr{$layer} .= "<text x=\"$x\" y=\"$y\" font-size=\"$fontsize\" font-family=\"$fontfam\" fill=\"$fgcolor\" $alignxstr $alignystr >".$str."</text>\n";
}

sub printtextrot {
    my ($x, $y, $a, $str) = @_;
    
    $svglayerstr{$layer} .= "<g transform=\"translate($x,$y)\">\n";
    $svglayerstr{$layer} .= "<g transform=\"rotate($a)\">\n";
    $svglayerstr{$layer} .= "<text x=\"0\" y=\"0\" font-size=\"$fontsize\" font-family=\"$fontfam\" fill=\"$fgcolor\" text-anchor=\"middle\" dominant-baseline=\"central\">";
    $svglayerstr{$layer} .= $str;
    $svglayerstr{$layer} .= "</text>\n</g>\n</g>\n";
}

sub printcircle {
    my ($x, $y, $r, $w) = @_;
    
    $svglayerstr{$layer} .= "<circle cx=\"$x\" cy=\"$y\" r=\"$r\" stroke=\"$fgcolor\" fill=\"none\" stroke-width=\"$w\"/>\n";
}

sub printfillcircle {
    my ($x, $y, $r) = @_;
    
    $svglayerstr{$layer} .= "<circle cx=\"$x\" cy=\"$y\" r=\"$r\" stroke=\"$fgcolor\" fill=\"$fgcolor\" stroke-width=\"1\"/>\n";
}

sub printtriangle {
    my ($x1, $y1, $x2, $y2, $x3, $y3) = @_;
    
    $svglayerstr{$layer} .= "<polygon points=\"$x1,$y1 $x2,$y2 $x3,$y3\" stroke=\"$fgcolor\" fill=\"$fgcolor\" stroke-width=\"1\"/>\n";
}

sub printheader() {
    print OUT <<HEAD;
<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<div style="width:800px; margin:0 auto;">
<svg width="100%" height="100%" viewBox="0 -1000 $viewwidth $viewheight" preserveAspectRatio="xMinYMin meet" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
HEAD
}

sub printfooter() {
    print OUT "</svg></div>\n";
}

sub dCircle {
    my ($level, $clr, $wd) = @_;
    
    my $ax;
    my $ay;
    my $fc = $fgcolor;
    
    $fgcolor = $clr;
    
    unless(defined($wd)) {
        $wd = $linewidth;
    }
    
    $ax = radialx($level*$xmult, 0);
    $ay = radialy($level*$xmult, 0);
    printcircle($rcx, $rcy, $xmult*$level, $wd);
    
    $fgcolor = $fc;
}

sub dText {
    my ($x, $y, $str) = @_;
    
    my $ax;
    my $ay;
    
    $ax = radialx($x*$xmult, $y);
    $ay = radialy($x*$xmult, $y);
    printtext($ax, $ay, $str, "center", "center");
}

sub dRText {
    my ($x, $y, $str, $unit) = @_;
    
    my $ax;
    my $ay;
    my $a;
    
    $ax = radialx($x*$xmult, $y);
    $ay = radialy($x*$xmult, $y);
    $a = (-$direction * $y * $ymult) + $rotation + 180;
    
    if($unit eq "kb") {
        $str = ($str/1000)."kb";
    }
    
    printtextrot($ax, $ay, $a, $str);
}

sub dPoint {
    my ($y, $x, $clr) = @_;
    
    my $ax;
    my $ay;
    my $fc = $fgcolor;
    
    $fgcolor = $clr;
    
    $ax = radialx($x*$xmult, $y);
    $ay = radialy($x*$xmult, $y);
    printfillcircle($ax, $ay, $linewidth*5);
    
    $fgcolor = $fc;
}

sub dStack {
    my ($y, $x, $h, $clr) = @_;
    
    my $ax;
    my $ay;
    my $fc = $fgcolor;
    
    $fgcolor = $clr;
    
    $ax = radialx(($x * $xmult) + ($linewidth * $stackradius * 2 * $h), $y);
    $ay = radialy(($x * $xmult) + ($linewidth * $stackradius * 2 * $h), $y);
    printfillcircle($ax, $ay, $linewidth * $stackradius);
    
    $fgcolor = $fc;
}

sub dArc {
    my ($y1, $y2, $x, $clr) = @_;
    
    my $fc = $fgcolor;
    my $ax1;
    my $ay1;
    my $ax2;
    my $ay2;
    
    if($direction == -1) {  #if clockwise, switch order
        my $tmp = $y1;
        $y1 = $y2;
        $y2 = $tmp;
    }
    
    $fgcolor = $clr;
    
    $ax1 = radialx($x*$xmult, $y1);
    $ay1 = radialy($x*$xmult, $y1);
    $ax2 = radialx($x*$xmult, $y2);
    $ay2 = radialy($x*$xmult, $y2);
    printarc($ax1, $ay1, $ax2, $ay2, $x*$xmult, ((($y2-$y1)*$ymult*$direction<180)?0:1) );
    
    $fgcolor = $fc;
}

sub dBand {
    my ($y1, $y2, $x, $clr) = @_;
    
    my $fc = $fgcolor;
    my $lw = $linewidth;
    my $ax1;
    my $ay1;
    my $ax2;
    my $ay2;
    
    if($direction == -1) {  #if clockwise, switch order
        my $tmp = $y1;
        $y1 = $y2;
        $y2 = $tmp;
    }
    
    $fgcolor = $clr;
    $linewidth = $bandwidth;
    
    $ax1 = radialx($x*$xmult, $y1);
    $ay1 = radialy($x*$xmult, $y1);
    $ax2 = radialx($x*$xmult, $y2);
    $ay2 = radialy($x*$xmult, $y2);
    printarc($ax1, $ay1, $ax2, $ay2, $x*$xmult, ((($y2-$y1)*$ymult*$direction<180)?0:1) );
    
    $fgcolor = $fc;
    $linewidth = $lw;
}

sub dThinBand {
    my ($y1, $y2, $x, $clr) = @_;
    
    my $fc = $fgcolor;
    my $lw = $linewidth;
    my $ax1;
    my $ay1;
    my $ax2;
    my $ay2;
    
    if($direction == -1) {  #if clockwise, switch order
        my $tmp = $y1;
        $y1 = $y2;
        $y2 = $tmp;
    }
    
    $fgcolor = $clr;
    $linewidth = $thinbandwidth;
    
    $ax1 = radialx($x*$xmult, $y1);
    $ay1 = radialy($x*$xmult, $y1);
    $ax2 = radialx($x*$xmult, $y2);
    $ay2 = radialy($x*$xmult, $y2);
    printarc($ax1, $ay1, $ax2, $ay2, $x*$xmult, ((($y2-$y1)*$ymult*$direction<180)?0:1) );
    
    $fgcolor = $fc;
    $linewidth = $lw;
}

sub dLine {
    my ($x1, $y1, $x2, $y2, $clr) = @_;
    
    my $fc = $fgcolor;
    my $ax1;
    my $ay1;
    my $ax2;
    my $ay2;
    
    $fgcolor = $clr;
    
    $ax1 = radialx($x1*$xmult, $y1);
    $ay1 = radialy($x1*$xmult, $y1);
    $ax2 = radialx($x2*$xmult, $y2);
    $ay2 = radialy($x2*$xmult, $y2);
    printline($ax1, $ay1, $ax2, $ay2);
    
    $fgcolor = $fc;
}

sub drawLevel {
    my ($level, $type, $clrline, $clrfill) = @_;
    
    unless(length($clrline) > 0) {
        $clrline = $fgcolor;
    }
    
    my $llow = (($level*$xmult) - ($bandwidth/2)) / $xmult;
    my $lmid = $level;
    my $lhigh = (($level*$xmult) + ($bandwidth/2)) / $xmult;
    
    if(defined($clrfill)) {
        dCircle($lmid, $clrfill, $bandwidth);
    }
    
    if($type =~ /low/i) {
        dCircle($llow, $clrline);
    }
    if($type =~ /mid/i) {
        dCircle($lmid, $clrline);
    }
    if($type =~ /high/i) {
        dCircle($lhigh, $clrline);
    }
}

sub drawScale {
    my ($level, $type, $clr) = @_;
    
    my ($tictype, $ticunit) = split(/,/, $type);
    my $ticstr = "";
    
    if($ticunit =~ /^(\d+)kb$/i) {
        $ticunit = $1*1000;
        $ticstr = "kb";
    }
    
    unless(length($clr) > 0) {
        $clr = $fgcolor;
    }
    
    dCircle($level, $clr);
    
    my $lin = (($level*$xmult) - ($ticsize)) / $xmult;
    my $lmid = $level;
    my $lout = (($level*$xmult) + ($ticsize)) / $xmult;
    my $ltext = (($level*$xmult) + ($ticsize * 3)) / $xmult;
    
    if($tictype =~ /in/i) {  # text on inside only if tics on inside
        $ltext = (($level*$xmult) - ($ticsize * 3)) / $xmult;
    }
    
    my $lw = $linewidth;
    $linewidth = $lw * 4;
    
    dLine($lin, $maxposnum, $lout, $maxposnum, $fgcolor);  # thicker end-join line
    
    $linewidth = $lw;
    
    for(my $y=$ticunit; $y<=$maxposnum; $y+=$ticunit) {
        if($tictype =~ /in/i) {
            dLine($lmid, $y, $lin, $y, $fgcolor);
        } elsif($tictype =~ /out/i) {
            dLine($lmid, $y, $lout, $y, $fgcolor);
        } elsif($tictype =~ /cross/i) {
            dLine($lin, $y, $lout, $y, $fgcolor);
        }
        
        if($tictype =~ /label/i) {
            dRText($ltext, $y, $y, $ticstr);
        }
    }
}

sub drawPoint {
    my ($p, $level, $clr) = @_;
    
    dPoint($p, $level, $clr);
}

sub drawStack {
    my ($p, $level, @clrlist) = @_;
    
    for(my $i=0; $i<scalar(@clrlist); $i++) {
        dStack($p, $level, $i, $clrlist[$i]);
    }
}

sub drawRegion {
    my ($s, $e, $level, $clr, $dir) = @_;
    
    # add directional arrows here based on $dir

    dBand($s, $e, $level, $clr);
}

sub drawThinRegion {
    my ($s, $e, $level, $clr) = @_;
    
    dThinBand($s, $e, $level, $clr);
    
    my $llow = (($level*$xmult) - ($bandwidth/4)) / $xmult;
    my $lhigh = (($level*$xmult) + ($bandwidth/4)) / $xmult;
    
    dLine($llow, $s, $lhigh, $s, $fgcolor);
    dLine($llow, $e, $lhigh, $e, $fgcolor);
}

sub drawTitle {
    my $str = shift;
    
    dText(0, 1, $str);
}

sub drawOrigin {
    my ($level, $p, $fr, $ud, $clr) = @_;
    
    my $arclen = 5; # degrees of arc length
    
    my $llow = (($level*$xmult) - ($bandwidth/2)) / $xmult;
    my $lhigh = (($level*$xmult) + ($bandwidth/2)) / $xmult;
    my $larc;
    my $p2;
    my $p3;
    my $arcdir = $direction * ($fr =~ /for/i);
    
    if($fr =~ /for/i) {
        $p2 = $p + ($arclen * $posrange / 360);
        $p3 = $p2 - ($p2-$p)*0.1;
    } else {
        $p2 = $p - ($arclen * $posrange / 360);
        $p3 = $p2 + ($p-$p2)*0.1;
    }
    
    if($ud =~ /up/i) {
        $larc = $lhigh = (($level*$xmult) + $bandwidth) / $xmult;
    } else {
        $larc = $llow = (($level*$xmult) - $bandwidth) / $xmult;
    }
    
    dLine($llow, $p, $lhigh, $p, $fgcolor);
    
    if($arcdir == $direction) {
        dArc($p, $p2, $larc, $fgcolor);
    } else {
        dArc($p2, $p, $larc, $fgcolor);
    }
    
    # draw arrow head
    dLine($larc, $p2, ($larc*$xmult - $bandwidth*0.15)/$xmult, $p3, $fgcolor);
    dLine($larc, $p2, ($larc*$xmult + $bandwidth*0.15)/$xmult, $p3, $fgcolor);
}

### MAIN ###

GetOptions (
    "f"   => \$forceoverwrite,
    "h"   => \$showhelp,
    "i=s" => \$infile,
    "o=s" => \$outfile
);

if($infile eq '-') {
    $useSTDIN = 1;
}

my $help = <<HELP;
SVG Large Annotated Circular Gene map (slacGene) v1.0
Created by John P. McCrow (12/10/2014)

Usage: slacGene.pl (options)

options:
    -f            force overwrite of output file (default: no overwrite)
    -h            show help
    -i file       input file (use '-' for STDIN)
    -o file       output file (default: STDOUT)

HELP

if($showhelp ||
    !($useSTDIN || length($infile)>0)) {
    
    die $help;
}

init_config();

open_handles();

readannotations();

unless(checkparams()) {
    die "Exit: not all parameters set within limits\n";
}

calcscaleparams();

#Draw regions and points
$layer = layer_gene;

foreach my $l (sort {$a<=>$b} keys %all_levels) {
    if(exists($levlist_type{$l})) {
        for(my $i=0; $i<scalar(@{$levlist_type{$l}}); $i++) {
            my $type = @{$levlist_type{$l}}[$i];
            my $val = @{$levlist_val{$l}}[$i];
            my $dir = @{$levlist_dir{$l}}[$i];
            my $clr = @{$levlist_clr{$l}}[$i];
            my $clr2 = @{$levlist_clr2{$l}}[$i];
            
            if($type eq 'region') {
                my ($s, $e) = split(/,/, $val);
                drawRegion($s, $e, $l, $clr, $dir);
                
            } elsif($type eq 'line') {
                my ($s, $e) = split(/,/, $val);
                drawThinRegion($s, $e, $l, $clr);
                
            } elsif($type eq 'point') {
                drawPoint($val, $l, $clr);
                
            } elsif($type eq 'stack') {
                my ($p, $h) = split(/,/, $val);
                drawStack($p, $l, @{$levstack_clrlist{$l}{$p}});
                
            } elsif($type eq 'level') {
                drawLevel($l, $val, $clr, $clr2);
                
            } elsif($type eq 'scale') {
                drawScale($l, $val, $clr);
            
            } elsif($type eq 'origin') {
                my ($p, $fr, $ud) = split(/,/, $val);
                drawOrigin($l, $p, $fr, $ud, $clr);
                
            } else {
                die "Unknown annotation type: $type\n";
            }
        }
    }
}

#Draw text
$layer = layer_text;

if(length($titlestr) > 0) {
    drawTitle($titlestr);
}

#Print SVG in ordered layers
printheader();

foreach $layer (sort {$a<=>$b} keys %svglayerstr) {
  print OUT $svglayerstr{$layer};
}

printfooter();
