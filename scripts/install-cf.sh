#! /bin/bash

checkProject()
{
    # link between PROJECT file and a symbolic name
    projectLinks ${BASE_PATH}/src/cf-dkrz.cpp
    projectLinks ${BASE_PATH}/include/cf-dkrz.h

    if [ ${BIN:-f} = f -o ${BASE_PATH:-f} = f ] ; then
       if [ ${BIN:-f} = f ] ; then
          echo "Please, set BIN variable in the install script."
       else
          echo "BASE_PATH: unrecognised path to the ${package} package."
       fi

       exit
    fi

    # nothing to protect
    export EXE_NAME=qC-${PROJECT}

    if ! make ${always} -q -C $BIN -f ${BASE_PATH}/Makefile ; then
       # not up-to-date
       if make ${always} ${mk_D} -C $BIN -f ${BASE_PATH}/Makefile ; then
         log "make qc-${PROJECT}.x" DONE
       else
         log "make qc-${PROJECT}.x" FAIL
         exit
       fi
    fi

    test ${EXE_NAME:0:3} = qqC && mv $BIN/${EXE_NAME}.x $BIN/qC-${PROJECT}.x

  return
}

checkPath()
{
  # Note: each executable invoked on a bash command-line
  # gets its name in parameter $0, which is unchanged
  # in a function.

  # was the call for any (relative) path to QC-??/scripts ?
  test ! -z ${0%install.sh} && cd ${0%/*}/.. &> /dev/null

  BASE_PATH=$(pwd)

  return
}

compilerSetting()
{
  # Notice priority
  local locCC locCFLAGS locCXX locCXXFLAGS
  local lf

  # external setting gets highest priority
  locCC="$CC"
  locCFLAGS="$CFLAGS"
  locCXX="$CXX"
  locCXXFLAGS="$CXXFLAGS"

  # Anything given in the install_configure file?
  if [ -f install_configure ] ; then
    . install_configure

    log "apply install_configure settings" DONE
  fi

  if [ ${#locCC} -gt 0 ] ; then
    CC="${locCC}"
    log "export CC=${locCC}" DONE
  fi
  if [ ${#locCFLAGS} -gt 0 ] ; then
    CFLAGS="${locCFLAGS}"
  fi
  if [ ${#locCXX} -gt 0 ] ; then
    CXX="${locCXX}"
    log "export CXX=${locCXX}" DONE
  fi
  if [ ${#locCXXFLAGS} -gt 0 ] ; then
    CXXFLAGS="${locCXXFLAGS}"
    log "export CXXFLAGS=${locCXXFLAGS}" DONE
  fi

  # no external setting, try for gcc/g++
  local tmp
  if [ ${#CC} -eq 0 ] ; then
     if tmp=$(which gcc) ; then
        CC=$tmp
        log "default: export CC=${tmp}" DONE
     fi
  fi

  if [ ${#CFLAGS} -eq 0 ] ; then
    CFLAGS="-O2"
    log "default: export CFLAGS=-O2" DONE
  fi

  if [ ${#CXX} -eq 0 ] ; then
     if tmp=$(which g++) ; then
        CXX=$tmp
        log "default: export CXX=${tmp}" DONE
     fi
  fi

  if [ ${#CXXFLAGS} -eq 0 ] ; then
    CXXFLAGS="-O2"
    log "default: export CXXFLAGS=-O2" DONE
  fi

  if [ ! -f install_configure ] ; then
    txt="${txt}# ============ Please, edit setting ========="
    txt="${txt}\n# ============ Assignment containing spaces must be surrounded by \""

    txt="${txt}\n\n# C compiler"
    txt="${txt}\nCC=\"${CC}\""

    txt="${txt}\n\n# C++ compiler"
    txt="${txt}\nCXX=\"${CXX}\""

    txt="${txt}\n\n# C compiler options"
    txt="${txt}\nCFLAGS=\"${CFLAGS}\""

    txt="${txt}\n\n# C++ compiler options"
    txt="${txt}\nCXXFLAGS=\"${CXXFLAGS}\""

    txt="${txt}\n\n# Path to NetcCDF libraries."
    txt="${txt}\n# Prefix of '-L' may be skipped."
    txt="${txt}\nLIB="

    txt="${txt}\n\n# Path to NetCDF header files."
    txt="${txt}\n# Prefix of '-I' may be skipped."
    txt="${txt}\nINCLUDE="

    txt="${txt}\n\n# path to place QC executables."
    txt="${txt}\n# Default: path/$package/bin"
    txt="${txt}\n# If the path is relative, then the default is extended."
    txt="${txt}\n#BIN=$(pwd)/bin"

    echo -e "${txt}" > install_configure
    log "create install_configure" DONE

  fi

  # --only-qc-src
  test "${isNoBuild}" = t && exit

  FC=""
  F90=""

  return
}

descript()
{
  echo "usage: scripts/install.sh"
  echo "  -B                Unconditionally re-make all"
  echo "  -c                Exit after creation of script 'install_configure'."
  echo "  -d                Execute 'make' with debugging info."
  echo "  --continue_log    Iternal processing option."
  echo "  --debug[=script]  Display execution commands."
  echo "  --help            Also option -h."
  echo "  --link=path       Link lib and include files, respectively, of external netcdf"
  echo "                    to the directories 'your-path/${package}/local'."
  echo "  --only-qc-src         Get ${package} sources and create install_configure."
  echo "  --package=str     str=QC-version."
  echo "  --reset_tables    Remove every table in ${package}/tables having an"
  echo "                    entry of the same name in ${package}/tables/projects."
  echo "  --show-inst       Display properties of the current installation."
  echo "  --src-path=path   To the place were all three libs reside."
  echo "    project-name    At present CMIP5 and CORDEX."
  echo "                    Installation for both by default. Note: no '--'."
}

expandLIB_INCLUDE()
{
   local is

   LIB="${LIB//-L}"
   LIB="${LIB/#/-L}"
   LIB="${LIB/ / -L}"
   LIB="${LIB/:/ -L}"

   INCLUDE=${INCLUDE//-I}
   INCLUDE=${INCLUDE/#/-I}
   INCLUDE=${INCLUDE/ / -I}
   INCLUDE=${INCLUDE/:/ -I}

   local is_i=( f f f f )
   local is_l=( f f f f )
   local item

   # ----check include file
   for item in ${INCLUDE} ; do
     test -e ${item:2}/zlib.h && is_i[0]=t
     test -e ${item:2}/hdf5.h && is_i[1]=t
     test -e ${item:2}/netcdf.h && is_i[2]=t
     test -e ${item:2}/udunits2.h && is_i[3]=t
   done

   # ----check lib files
   # note that static and/or shared as well as lib and/or lib64 may occur
   local j tp typ kind isShared isStatic
   typ=( a so )

   local isShared=( f f f f )
   local isStatic=( f f f f )

   for tp in a so ; do
     for item in ${LIB[*]} ; do
       if [ -e ${item:2}/libz.${tp} ] ; then
          is_l[0]=t

          if [ ${tp} = a ] ; then
            isStatic[0]=t
          else
            isShared[0]=t
          fi
       fi
       if [ -e ${item:2}/libhdf5_cpp.${tp} ] ; then
          is_l[1]=t

          if [ ${tp} = a ] ; then
            isStatic[1]=t
          else
            isShared[1]=t
          fi
       fi
       if [ -e ${item:2}/libnetcdf.${tp} ] ; then
          is_l[2]=t

          if [ ${tp} = a ] ; then
            isStatic[2]=t
          else
            isShared[2]=t
          fi
       fi
       if [ -e ${item:2}/libudunits2.${tp} ] ; then
          is_l[3]=t

          if [ ${tp} = a ] ; then
            isStatic[3]=t
          else
            isShared[3]=t
          fi
       fi
     done
   done

   local isS=f
   for(( i=0 ; i < ${#isShared[*]} ; ++i )) ; do
      test ${isShared[i]} = ${isStatic[i]} && isStatic[i]=f
      test ${isStatic[i]} = t && isS=t
   done

   if [ ${isS} = t ] ; then
      local dls
      dls=( $( find /lib -name "libdl.*" 2> /dev/null ) )
      test ${#dls[*]} -eq 0 && \
          dls=( $( find /usr/lib -name "libdl.*" 2> /dev/null ) )

      test ${#dls[*]} -gt 0 && export LIBDL='-ldl'
   fi

  local isI=t
  local isL=t

  for(( i=0 ; i < ${#is_i[*]} ; ++i )) ; do
    test ${is_i[i]} = f && isI=f
    test ${is_l[i]} = f && isL=f
  done

  if [ ${isI} = f -o ${isL} = f ] ; then
     echo "At least one path in"
     echo -e "\t ${LIB[*]}"
     echo -e "or \t ${INCLUDE[*]}"
     echo "is broken."

     showInst
     exit 1
  fi

  export CC CXX CFLAGS CXXFLAGS FC F90
  export LIB INCLUDE BASE_PATH

  return
}

formatText()
{
  # format text ready for printing

  # date and host
  local k N n str0 str isWrap

  str0="$*"

  # The total output is subdivided into chunks of pmax characters.
  # Effect of \n is preserved.
  N=$pEnd  # special: taken from log()
  str=

  while : ; do
    k=0  # necessary when skipping the loop

    if [ ${isWrap:-f} = t ] ; then
      n=$(( N - 6 ))
    else
      n=$N
    fi

    if [ ${#str0} -ge $n ] ; then
      # wrap lines with length > N
      for (( ; k < n ; ++k )) ; do
        if [ "${str0:k:2}" = "\n" ] ; then
          str="${str}${str0:0:k}\n"
          str0=${str0:$((k+2))}
          isWrap=f
          continue 2
        fi
      done
    fi

    # the last line
    if [ ${#str0} -le $n ] ; then
      str="${str}${str0}"
      break

    # sub-lines length equals N
    elif [ $k -eq $n -a "${str0:k:2}" = "\n" ] ; then
      str="${str}${str0:0:n}"
      str0=${str0:n}

    # wrap line
    else
      str="${str}${str0:0:n}\n      "
      str0=${str0:n}
      isWrap=t
    fi
  done

  if [ ${isWrap:-f} = t ] ; then
    lastLineSz=$(( ${#str0} + 6 ))
  else
    lastLineSz=${#str0}
  fi

  formattedText=${str}
}

getRevNum()
{
  # get the number saved in QC_SRC/.conf as revision=num
  local rev
  rev=$( grep 'revision=' .conf 2> /dev/null \
       | awk -F= '{print $2}' )

  eval $1=${rev:--1}

  return
}

libInclSetting()
{
   LIB="${LIB//-L}"
   INCLUDE=${INCLUDE//-I}

   export CC CXX CFLAGS CXXFLAGS FC F90
   export LIB INCLUDE BASE_PATH

   local i

   if [ ${#link} -eq 0 ] ; then
     local isEmpty lib
     isEmpty=t
     lib=( ${LIB//:/ } )

     # any netcdf lib in the path of install_configure?
     for(( i=0 ; i < ${#lib[*]} ; ++i )) ; do
       if ls  ${lib[i]}/libnetcdf.* &> /dev/null ; then
          isEmpty=f
       fi
     done

     if [ ${isEmpty} = t ] ; then
        # any netcdf lib in QC/local?
        lib=( local/lib local/lib )

        for(( i=0 ; i < ${#lib[*]} ; ++i )) ; do
          if ls  ${lib[i]}/libnetcdf.* &> /dev/null ; then
             isEmpty=f
          fi
        done

        test ${isEmpty} = t && LIB=
     fi
   fi

   if [ ${isBuild:-f} = t -o ${#link} -gt 0  -o  ${#LIB} -eq 0 ] ; then
     # install zlib, hdf5, and/or netcdf.
     # LIB and INCLUDE, respectively, are colon-separated singles
     if bash scripts/install_local ${coll[*]} ; then
       unset link
       isBuild=f
     else
       exit 1
     fi

     compilerSetting
     libInclSetting

     return
   fi

   LIB="${LIB/#/-L}"
   LIB="${LIB/ / -L}"
   LIB="${LIB/:/ -L}"

   INCLUDE=${INCLUDE/#/-I}
   INCLUDE=${INCLUDE/ / -I}
   INCLUDE=${INCLUDE/:/ -I}

   local is

   local is_i=( f f f f )
   local is_l=( f f f f )
   local item

   # ----check include file
   for item in ${INCLUDE[*]} ; do
     test -e ${item:2}/zlib.h && is_i[0]=t
     test -e ${item:2}/hdf5.h && is_i[1]=t
     test -e ${item:2}/netcdf.h && is_i[2]=t
     test -e ${item:2}/udunits2.h && is_i[3]=t
   done

   # ----check lib
   # note that static and/or shared as well as lib and/or lib64 may occur
   local j tp typ kind isShared isStatic
   typ=( a so )

   local isShared=( f f f f )
   local isStatic=( f f f f )

   for tp in a so ; do
     for item in ${LIB[*]} ; do
       if [ -e ${item:2}/libz.${tp} ] ; then
          is_l[0]=t

          if [ ${tp} = a ] ; then
            isStatic[0]=t
          else
            isShared[0]=t
          fi
       fi
       if [ -e ${item:2}/libhdf5.${tp} ] ; then
          is_l[1]=t

          if [ ${tp} = a ] ; then
            isStatic[1]=t
          else
            isShared[1]=t
          fi
       fi
       if [ -e ${item:2}/libnetcdf.${tp} ] ; then
          is_l[2]=t

          if [ ${tp} = a ] ; then
            isStatic[2]=t
          else
            isShared[2]=t
          fi
       fi
       if [ -e ${item:2}/libudunits2.${tp} ] ; then
          is_l[3]=t

          if [ ${tp} = a ] ; then
            isStatic[3]=t
          else
            isShared[3]=t
          fi
       fi
     done
   done

   local isS=f
   for(( i=0 ; i < ${#isShared[*]} ; ++i )) ; do
      test ${isShared[i]} = ${isStatic[i]} && isStatic[i]=f
      test ${isStatic[i]} = t && isS=t
   done

   if [ ${isS:-f} = t ] ; then
      local dls
      dls=( $( find /lib -name "libdl.*" 2> /dev/null ) )
      test ${#dls[*]} -eq 0 && \
          dls=( $( find /usr/lib -name "libdl.*" 2> /dev/null ) )

      test ${#dls[*]} -gt 0 && export LIBDL='-ldl'
   fi

  local isI=t
  local isL=t

  for(( i=0 ; i < ${#is_i[*]} ; ++i )) ; do
    test ${is_i[i]} = f && isI=f
    test ${is_l[i]} = f && isL=f
  done

  if [ ${isI} = f -o ${isL} = f ] ; then
     echo "At least one path in"
     for(( i=0 ; i < ${#LIB[*]} ; ++i )) ; do
       echo -e "\t ${LIB[i]}"
     done
     echo -e "or \t ${INCLUDE[*]}"
     echo "is broken."

     showInst
     exit 1
  fi


  return
}

localClean()
{
  if [ "${1}" = a ] ; then
    for f in bin include lib lib64 share ; do
      \rm -rf local/$f
    done
  elif [ "${1}" = h ] ; then
     \rm -f local/bin/gifh25     local/bin/h5*
     \rm -f local/include/H5*    local/include/hdf5*
     \rm -f local/lib/libhdf*
     \rm -rf local/share
  elif [ "${1}" = n ] ; then
     \rm -f local/bin/nc*
     \rm -f local/include/netcdf*
     \rm -f local/lib/libnetcdf* local/lib/pkconfig/netcdf.pc
  elif [ "${1}" = z ] ; then
    \rm -f local/include/z*
    \rm -f local/lib/libz.a      local/lib/pkconfig/zlib.pc
  fi

  return
}


projectLinks()
{
  local file=$1
  local type
  local i

  if [ ${file##*.} = cpp ] ; then
    type=cpp
  elif [ ${file##*.} = h ] ; then
    type=include
  fi

  if [ -e $file ] ; then
    local items=( $( ls -l $file 2> /dev/null ) )
    for(( i=0 ; i < ${#items[*]} ; ++i )) do
      if [ "${items[i]}" = '->' ] ; then
        i=$(( i + 1 ))
        if expr match ${items[i]} ".*${PROJECT}" &> /dev/null ; then
          # it's all right; nothing to do
          return
        else
          # establish a new link below
          break
        fi
      fi
    done

    # not a symbolic link, but a real file
    test $i -eq ${#items[*]} && \rm -f $file 2> /dev/null
  fi

  if [ ${type:-f} = cpp ] ; then
     ln -sf ${BASE_PATH}/src/QC_${PROJECT}.cpp ${BASE_PATH}/src/QC.cpp
  elif [ ${type:-f} = include ] ; then
     ln -sf ${BASE_PATH}/include/qc_${PROJECT}.h ${BASE_PATH}/include/qc.h
  fi

  return
}

showInst()
{
   echo "State of current QC Installation:"
   echo "======================="
   echo "CC=$CC"
   echo "CXX=$CXX"
   echo "CFLAGS=$CFLAGS"
   echo "CXXFLAGS=$CXXFLAGS"
   echo "OSTYPE=$OSTYPE"
   echo "BASH=$(bash --version | head -n 1)"
   echo -e "\nBIN=${BIN}: "
   fs=($( ls -d ${BIN}/*))
   if [ ${#fs[*]} -gt 1 ] ; then
     echo -e "\t${fs[*]##*/}"
   fi

   local is=( f f f f )
   local text=( "zlib" "hdf5" "netCDF" "udunits" )

   local item

   # ----check include file
   echo -e "\nINCLUDE=${INCLUDE}"

   for item in ${INCLUDE} ; do
     test -e ${item:2}/zlib.h && is[0]=t
     test -e ${item:2}/hdf5.h && is[1]=t
     test -e ${item:2}/netcdf.h && is[2]=t
     test -e ${item:2}/udunits2.h && is[3]=t
   done

   local i
   for(( i=0 ; i < ${#is[*]} ; ++i )) ; do
     echo -e -n "\t${text[i]}\t: "
     if [ ${is[i]} = t  ] ; then
        echo "yes"
      else
        echo "no"
      fi
   done

   # ----check lib files

   echo -e "\nLIB=${LIB}"

   local j typ kind
   typ=( a so )
   kind=( static shared )

   for(( j=0 ; j < ${#typ[*]} ; ++j )) ; do
     is=( f f f f )

     for item in ${LIB} ; do
       test -e ${item:2}/libz.${typ[j]} && is[0]=t
       test -e ${item:2}/libhdf5_cpp.${typ[j]} && is[1]=t
       test -e ${item:2}/libnetcdf.${typ[j]} && is[2]=t
       test -e ${item:2}/libudunits2.${typ[j]} && is[3]=t
     done

     for(( i=0 ; i < ${#is[*]} ; ++i )) ; do
       echo -e -n "\t${text[i]} (${kind[j]})\t: "
       if [ ${is[i]} = t ] ; then
         echo "yes"
       else
         echo "no"
       fi
     done
   done

   # ----check ncdump executable
   is=f
   for item in ${LIB} ; do
     item=${item:2}
     if [ -e ${item%/*}/bin/ncdump ] ; then
       is=t
       break
     fi
   done

   if [ ${is} = t ] ; then
     echo -e "\nNCDUMP=$( ${item%/*}/bin/ncdump 2>&1 | tail -n 1 )"
   else
     echo -e "\nncdump: no such file"
   fi

   # -------------------

   cd $BASE_PATH &> /dev/null

   test ${isShowInstFull:-f} = f && return

   echo -e "\ninstall_configure:"
   cat install_configure

   echo -e "\nQC Directories/Files"
   echo -e "\n${package}:"
   ls -d *
   echo -e "\n${package}/bin:"
   ls -l bin/*
   echo -e "\n${package}/include:"
   ls -l include/*
   echo -e "\n${package}/src:"
   ls -l src/*

   if [ -e "local" ] ; then
     echo -e "\n${package}/local:"
     ls -d local/*
   fi

   if [ -e local/lib ] ; then
     echo -e "\n${package}/local/lib:"
     ls -ld local/lib/*
   fi

   return
}

store_LD_LIB_PATH()
{
  # paths to shared libraries

  # current -L paths
  local i j lib
  lib=( ${LIB[*]//-L/} )
  lib=( ${lib[*]//:/ } )

  local ldp
  for(( i=0 ; i < ${#lib[*]} ; ++i )) ; do
    test ${#ldp} -gt 0 && ldp=${ldp}:
    ldp=${ldp}${lib[i]}
  done

  # get those used for the compilation stored in .conf
  local tmp tmps
  tmp="$( grep 'LD_LIBRARY_PATH=' .conf 2> /dev/null)"
  tmp="${tmp[*]#LD_LIBRARY_PATH=}"

  if [ ${#tmp} -eq 0 ] ; then
    # initial write
    echo "LD_LIBRARY_PATH=${ldp}" >> .conf
  elif [ "$tmp" != "$ldp" ] ; then
    sed -i "/LD_LIBRARY_PATH=/ c LD_LIBRARY_PATH=${ldp}" .conf
  fi

   # current LD_LIB_PATH paths
  local ld_lp
  ld_lp=( ${LD_LIBRARY_PATH//:/ } )

  local is isXport
  for(( i=0 ; i < ${#lib[*]} ; ++i )) ; do
    is=t
    for(( j=0 ; j < ${#ld_lp[*]} ; ++j )) ; do
      test "${lib[i]}" = "${ld_lp[j]}" && break
    done

    if [ ${j} -eq ${#ld_lp[*]} ] ; then
       test ${#LD_LIBRARY_PATH} -gt 0 && LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:
       LD_LIBRARY_PATH=${LD_LIBRARY_PATH}${lib[i]}
       isXport=t
    fi
  done

  test ${isXport:-f} = t && export LD_LIBRARY_PATH

  return
}

######### main ##########

mkdir -p local/source

while getopts Bcdh-: option ${args[*]}
do
  case $option in
    B)  always=-B ;;                # unconditionally make all
    c)  coll[${#coll[*]}]=-c ;;
    d)  mk_D=-d ;;                   # make with debugging info
    h)  descript
        exit ;;
    -)  if [ "${OPTARG}" = "build" ] ; then
           # make libraries in ${package}/local
           isBuild=t
        elif [ "$OPTARG" = "debug" ] ; then
           coll[${#coll[*]}]=--${OPTARG}
           if [ ${OPTARG} = debug -o ${OPTARG#*=} = 'install' ] ; then
             set -x
             isDebug=t
           fi
        elif [ "${OPTARG}" = distclean ] ; then
           isDistClean=t
           coll[${#coll[*]}]=--${OPTARG}
        elif [ "${OPTARG%%=*}" = "link" ] ; then
           localClean a
           link=${OPTARG#*=}
           coll[${#coll[*]}]=--${OPTARG}
        elif [ "${OPTARG%=*}" = "show-inst" ] ; then
           isShowInst=t
           test "${OPTARG#*=}" = "full" && isShowInstFull
        else
           coll[${#coll[*]}]=--${OPTARG}
        fi
        ;;
   \?)  descript
        echo $*
        exit 1;;
  esac
done

shift $(( $OPTIND - 1 ))

# get path
checkPath

# compiler settings
# import setting; these have been created during first installation
compilerSetting

# existence, linking or building
libInclSetting

store_LD_LIB_PATH

if [ ${#BIN} -gt 0 ] ; then
  test ${BIN:0:1} != '/' && BIN=${BASE_PATH}/$BIN
else
  BIN=${BASE_PATH}/bin
fi

# Note that any failure in a function called below causes an EXIT

if [ ${isShowInst:-f} = t ] ; then
  showInst
  exit
fi

# check projects' qc executables
projects=( $* )
test ${#projects[*]} -eq 0 && projects=( ${defaultProject} )

# the revision number is inserted in Makefile via -DSVN_VERSION
getRevNum SVN_VERSION
export SVN_VERSION

for prj in ${projects[*]} ; do
  # echeck project's executable
  checkProjects $prj

  # run example for CORDEX, if not done, yet
  runExample
done