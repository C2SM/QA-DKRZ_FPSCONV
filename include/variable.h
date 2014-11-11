#ifndef _VARIABLE_H
#define _VARIABLE_H

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "hdhC.h"

#include "geo_meta.h"
#include "nc_api.h"

#include "annotation.h"

/*! \file variable.h
 \brief Variable.
*/

  class GeoMetaBase ;
  class DataStatisticsBase ;
  class MtrxArrB ;
  class Base ;
  class InFile ;
  class NcAPI ;

//! Meta-data of a netCDF file for a particular variable.
class VariableMeta
{
  public:
  VariableMeta();

  void clearCoordStruct(void);

  std::string name;
  nc_type     type;
  size_t      dimSize;
  void       *fillValue;
  void       *missingValue;
  double      doubleFillValue;
  double      doubleMissingValue;
  double      scaleFactor;
  double      addOffset;
  double      range[2];
  bool        isUnitsDefined;
  std::string units;
  std::string canonical_units;
  std::vector<std::string>               attName;
  std::map<std::string, int>             attNameMap;
  std::vector<std::vector<std::string> > attValue;

  struct Coordinates
  {
     bool isAny;
     bool isCoordVar;   // coordinate variable, e.g. time(time) with units
     bool isT;
     bool isX;
     bool isY;
     bool isZ;
     bool isZ_DL;  //dimensionless coord

     int  indication_X;  // each evidence increments the value by 1
     int  indication_Y;
     int  indication_Z;
     int  indication_T;
  };
  Coordinates coord;

  bool isArithmeticMean; // externally set
  bool isChecked;
  bool isClimatology;
  bool isCompress;
  bool isDataVar;
  bool isDescreteSamplingGeom;
  bool isExcluded;
  bool isFixed;  // isTime==false && isDataVar==true
  bool isFillValue;
  bool isLabel;
  bool isMapVar;
  bool isMissingValue;
  bool isNoData;
  bool isScalar;
  bool is_ull_X;  // one-time switches in units_lon_lat()
  bool is_ull_Y;
  bool is_ull_rotX;
  bool is_ull_rotY;

  int  isUnlimited_;  // access by isUnlimited() method
  int  indication_DV;  // data variable

//  std::string associatedTo;
  std::string boundsOf;    // also for climatological statistics
  std::string bounds ;  // -"-
};

//! Container class for meta-data of a given variable.
/*! Provision of access to the meta-data, methods of the Base class
 by inheritance, MtrxArr instances and data statistics of read data.
 The Infile* points to the corresponding object where the opened
 nc-file resides and the NcAPI* to the nc-file itself.
 The GeoMeta object holds 2D and 3D geo-located fields of the
 variable (also giving access to the grid-cell areas, weights, and
 coordinates). Coordinates for multi-dimensionally expressed
 longitudes/latitudes, e.g. tripolar ocean data are recognised.*/
class Variable : public VariableMeta
{
  public:

  void clear(void);

  template<typename T>
  void setDefaultException(T, void *);

  template<typename T>
  void setExceptions( T*, MtrxArr<T>*) ;

  void disableAmbiguities(void);
  int  getAttIndex(std::string, bool tryLowerCase=true) ;
  // forceLowerCase==true will return the value always as lower-case
  std::string
       getAttValue(std::string, bool forceLowerCase=false);
  bool getData(NcAPI &, int rec, int leg=0);
  bool isCoordinate(void);
  int  getCoordinateType(void);  // X: 0, Y: 1, Z: 2, T: 3, any: 4, none: -1
  bool isValidAtt(std::string s, bool tryLowerCase=true);
  std::string
       getDimNameStr(bool isWithVar=false, char sep=',');
  bool isUnlimited(void) ;
  void makeObj(bool is);
  void setID(int i){id=i;}

  MtrxArr<char>               *mvCHAR;
  MtrxArr<signed char>        *mvBYTE;
  MtrxArr<unsigned char>      *mvUBYTE;
  MtrxArr<short>              *mvSHORT;
  MtrxArr<unsigned short>     *mvUSHORT;
  MtrxArr<int>                *mvINT;
  MtrxArr<unsigned int>       *mvUINT;
  MtrxArr<unsigned long long> *mvUINT64;
  MtrxArr<long long>          *mvINT64;
  MtrxArr<float>              *mvFLOAT;
  MtrxArr<double>             *mvDOUBLE;

  std::vector<std::string>    dimName;

  int                id;
  bool               isInfNan;

//    VariableMeta      *pMeta ;
  GeoMetaBase        *pGM;
  DataStatisticsBase *pDS;
  MtrxArrB           *pMA;
  Base               *pSrcBase;
  InFile             *pIn;
  NcAPI              *pNc;
};

#endif