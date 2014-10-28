#!/usr/bin/perl -I/opt/apps/psft/hr91/bin

#  Perl script to cleanup old files and directories.  It uses one argument
#  that is a file containing a list paths and cleanup parameters.
#  The format of a line in the file should be:
#
#  maintpath|arch days|archive name|delete days|exclude files
#
#  A file can contain many lines.  The maintpath and delete days are required.
#  If the archive days is left blank, the files are deleted from the maintpath.
#  If the archive days is set, the files are deleted from 
#  maintpath/archive name.
# Reddy

use kinLibCommon;

sub ExcludeFile ($)
{
   my ($file) = @_;
   my ($f, $path, $filename);

   ($path, $filename) = FileParts($file);
   foreach $f (@exc_files)
   {
      if ($filename eq $f)
      {
         return(1);
      }
   }
   return(0);
}

sub WalkDirectory($)
{
   my ($file) = @_;
   my ($f, $path, $dirname);

   ($path, $dirname) = FileParts($file);

   foreach $f (@exc_dirs)
   {
      if ($dirname =~ /$f/)
      {
         return(0);
      }
   }
   return(1);
}

sub ProcessFile($$)
{
   my ($file, $dir) = @_;
   my ($path, $dirname);
   
   ($path, $dirname) = FileParts($dir);

   if ($dirname eq "ARCHIVE")
   {
      if ((-d $file) && (-M $file > $deldays))
      {
         printf "rm -rf \"%s\"\n", $file;
         $cmd = sprintf "rm -rf \"%s\"", $file;
         system($cmd);
      }
      elsif ((-f $file) && (-M $file > $deldays+$arcdays))
      {
         printf "rm -f \"%s\"\n", $file;
         $cmd = sprintf "rm -f \"%s\"", $file;
         system($cmd);
      } 
   }
   else
   {
      if (! -d "$dir/ARCHIVE")
      {
         mkdir("$dir/ARCHIVE") || die "Could not create $dir/ARCHIVE";
      }
      if (! ExcludeFile($file) && (-M $file > $arcdays))
      {
         printf "mv -f \"%s\" %s/ARCHIVE\n", $file, $dir;
         $cmd = sprintf "mv -f \"%s\" %s/ARCHIVE", $file, $dir;
         system($cmd);
      }
   } 
}   
 

open(FP, "<$ARGV[0]") || die "Could not open $ARGV[0]";
@lines = <FP>;
close(FP);

foreach $line (@lines)
{
   chomp($line);
   ($maintpath, $arcdays, $deldays, $excdirs, $excfiles) = split /\|/, $line;

   @exc_files = split /,/, $excfiles;
   @exc_dirs = split /,/, $excdirs;

   if (! -d $maintpath)
   {
      printf "Maintenance path does not exist, aborting\n%s\n", $maintpath;
      next;
   }

   push @dirs, $maintpath;
   $dir = pop @dirs;
   while ($dir ne undef)
   {
      chdir ($dir);
      @files = glob("$dir/*");
      foreach $file (@files)
      {
         if (-d $file)
         {
            if (WalkDirectory($file))
            {
               printf "Add %s to stack\n", $file;
               push @dirs, $file;
            }
            else
            {
               ProcessFile($file, $dir);
            }
         }
         else
         {
            ProcessFile($file, $dir);
         }
      }
      $dir = pop @dirs;
   }
}

