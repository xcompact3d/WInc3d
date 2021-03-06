!################################################################################
!This file is part of Incompact3d.
!
!Incompact3d
!Copyright (c) 2012 Eric Lamballais and Sylvain Laizet
!eric.lamballais@univ-poitiers.fr / sylvain.laizet@gmail.com
!
!    Incompact3d is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation.
!
!    Incompact3d is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with the code.  If not, see <http://www.gnu.org/licenses/>.
!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
!    We kindly request that you cite Incompact3d in your publications and 
!    presentations. The following citations are suggested:
!
!    1-Laizet S. & Lamballais E., 2009, High-order compact schemes for 
!    incompressible flows: a simple and efficient method with the quasi-spectral 
!    accuracy, J. Comp. Phys.,  vol 228 (15), pp 5989-6015
!
!    2-Laizet S. & Li N., 2011, Incompact3d: a powerful tool to tackle turbulence 
!    problems with up to 0(10^5) computational cores, Int. J. of Numerical 
!    Methods in Fluids, vol 67 (11), pp 1735-1757
!################################################################################

!############################################################################
!
subroutine VISU_INSTA (ux1,uy1,uz1,phi1,ta1,tb1,tc1,td1,te1,tf1,tg1,th1,ti1,di1,&
     ta2,tb2,tc2,td2,te2,tf2,tg2,th2,ti2,tj2,di2,&
     ta3,tb3,tc3,td3,te3,tf3,tg3,th3,ti3,di3,phG,uvisu)
!
!############################################################################

USE param
USE var, only: FTx, FTy, FTz, Ftripx, GammaDisc,ep1, nut1, shrt_coeff
USE decomp_2d
USE decomp_2d_io

implicit none

TYPE(DECOMP_INFO) :: phG
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ux1,uy1,uz1,phi1
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ta1,tb1,tc1,td1,te1,tf1,tg1,th1,ti1,di1,tmp1
real(mytype),dimension(ysize(1),ysize(2),ysize(3)) :: ta2,tb2,tc2,td2,te2,tf2,tg2,th2,ti2,tj2,di2
real(mytype),dimension(zsize(1),zsize(2),zsize(3)) :: ta3,tb3,tc3,td3,te3,tf3,tg3,th3,ti3,di3
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ftx1, fty1, ftz1 
real(mytype),dimension(xszV(1),xszV(2),xszV(3)) :: uvisu 

integer :: code,icomplet
integer :: ijk,nvect1,nvect2,nvect3,i,j,k
character(len=20) nfichier,nfichier1
character(len=20) :: filename

nvect1=xsize(1)*xsize(2)*xsize(3)
!x-derivatives
call derx (ta1,ux1,di1,sx,ffx,fsx,fwx,xsize(1),xsize(2),xsize(3),0)
call derx (tb1,uy1,di1,sx,ffxp,fsxp,fwxp,xsize(1),xsize(2),xsize(3),1)
call derx (tc1,uz1,di1,sx,ffxp,fsxp,fwxp,xsize(1),xsize(2),xsize(3),1)
!y-derivatives
call transpose_x_to_y(ux1,td2)
call transpose_x_to_y(uy1,te2)
call transpose_x_to_y(uz1,tf2)
call dery (ta2,td2,di2,sy,ffyp,fsyp,fwyp,ppy,ysize(1),ysize(2),ysize(3),1)
call dery (tb2,te2,di2,sy,ffy,fsy,fwy,ppy,ysize(1),ysize(2),ysize(3),0)
call dery (tc2,tf2,di2,sy,ffyp,fsyp,fwyp,ppy,ysize(1),ysize(2),ysize(3),1)
!!z-derivatives
call transpose_y_to_z(td2,td3)
call transpose_y_to_z(te2,te3)
call transpose_y_to_z(tf2,tf3)
call derz (ta3,td3,di3,sz,ffzp,fszp,fwzp,zsize(1),zsize(2),zsize(3),1)
call derz (tb3,te3,di3,sz,ffzp,fszp,fwzp,zsize(1),zsize(2),zsize(3),1)
call derz (tc3,tf3,di3,sz,ffz,fsz,fwz,zsize(1),zsize(2),zsize(3),0)
!!all back to x-pencils
call transpose_z_to_y(ta3,td2)
call transpose_z_to_y(tb3,te2)
call transpose_z_to_y(tc3,tf2)
call transpose_y_to_x(td2,tg1)
call transpose_y_to_x(te2,th1)
call transpose_y_to_x(tf2,ti1)
call transpose_y_to_x(ta2,td1)
call transpose_y_to_x(tb2,te1)
call transpose_y_to_x(tc2,tf1)
!du/dx=ta1 du/dy=td1 and du/dz=tg1
!dv/dx=tb1 dv/dy=te1 and dv/dz=th1
!dw/dx=tc1 dw/dy=tf1 and dw/dz=ti1


!############################################################################
!VORTICITY
di1=0.
di1(:,:,:)=sqrt((tf1(:,:,:)-th1(:,:,:))**2+&
        (tg1(:,:,:)-tc1(:,:,:))**2+&
        (tb1(:,:,:)-td1(:,:,:))**2)
uvisu=0.
call fine_to_coarseV(1,di1,uvisu)
990 format('vort',I4.4)
write(filename, 990) itime/imodulo
call decomp_2d_write_one(1,uvisu,filename,2)
!call decomp_2d_write_one(nx_global,ny_global,nz_global,&
!     1,di1,filename)
!############################################################################


!############################################################################
! Q-criterion
!tmp1=0.
!do ijk=1,nvect1
!        tmp1(ijk,1,1)=ta1(ijk,1,1)*ta1(ijk,1,1)+te1(ijk,1,1)*te1(ijk,1,1)+ti1(ijk,1,1)*ti1(ijk,1,1)+ &
!            2*(td1(ijk,1,1)*tb1(ijk,1,1)+tg1(ijk,1,1)*tc1(ijk,1,1)+th1(ijk,1,1)*tf1(ijk,1,1))
!        tmp1(ijk,1,1)=tmp1(ijk,1,1)*0.5
!enddo
!uvisu=0.
!call fine_to_coarseV(1,tmp1,uvisu)
!991 format('qcrit',I4.4)
!write(filename, 991) itime/imodulo
!call decomp_2d_write_one(1,uvisu,filename,2)
!call decomp_2d_write_one(nx_global,ny_global,nz_global,&
!     1,di1,filename)
!############################################################################


!############################################################################
!VELOCITY
uvisu=0.
call fine_to_coarseV(1,ux1,uvisu)
993 format('ux',I4.4)
      write(filename, 993) itime/imodulo
call decomp_2d_write_one(1,uvisu,filename,2)
!call decomp_2d_write_one(nx_global,ny_global,nz_global,&
!           1,ux1,filename)
uvisu=0.
call fine_to_coarseV(1,uy1,uvisu)
994 format('uy',I4.4)
      write(filename, 994) itime/imodulo
call decomp_2d_write_one(1,uvisu,filename,2)
!call decomp_2d_write_one(nx_global,ny_global,nz_global,&
!           1,uy1,filename)
uvisu=0.
call fine_to_coarseV(1,uz1,uvisu)
995 format('uz',I4.4)
      write(filename, 995) itime/imodulo
call decomp_2d_write_one(1,uvisu,filename,2)
!call decomp_2d_write_one(nx_global,ny_global,nz_global,&
!           1,uz1,filename)
!############################################################################

!############################################################################
! Potential Temperature
if (ibuoyancy==1) then
uvisu=0.
call fine_to_coarseV(1,phi1,uvisu)
996 format('temp',I4.4)
   write(filename, 996) itime/imodulo
   call decomp_2d_write_one(1,uvisu,filename,2)
!   call decomp_2d_write_one(nx_global,ny_global,nz_global,&
!        1,phi1,filename)
endif

if (iadm==1) then
    uvisu=0.
    call fine_to_coarseV(1,GammaDisc,uvisu)
    997 format('gammadisc',I4.4)
    write(filename, 997) itime/imodulo
    call decomp_2d_write_one(1,uvisu,filename,2)    

endif
!############################################################################
!  ALM Momentum Source term
!if (ialm==1) then
!    uvisu=0.
!    do ijk=1,nvect1 
!      ftx1(ijk,1,1)=FTx(ijk,1,1)
!      fty1(ijk,1,1)=FTy(ijk,1,1)
!      ftz1(ijk,1,1)=FTz(ijk,1,1)
!    end do
!    
!    call fine_to_coarseV(1,ftx1,uvisu)
!    997 format('Ftx',I4.4)
!    write(filename, 997) itime/imodulo
!    call decomp_2d_write_one(1,uvisu,filename,2)    
!    uvisu=0.
!    call fine_to_coarseV(1,fty1,uvisu)
!    998 format('Fty',I4.4)
!    write(filename, 998) itime/imodulo
!    call decomp_2d_write_one(1,uvisu,filename,2)    
!    uvisu=0.
!    call fine_to_coarseV(1,ftz1,uvisu)
!    999 format('Ftz',I4.4)
!    write(filename, 999) itime/imodulo
!    call decomp_2d_write_one(1,uvisu,filename,2)    
!end if

if (itripping==1.or.itripping==2) then
    uvisu=0.
    call fine_to_coarseV(1,Ftripx,uvisu)
    998 format('Ftrip',I4.4)
    write(filename, 998) itime/imodulo
    call decomp_2d_write_one(1,uvisu,filename,2)    
endif

!##########################
! Immersed Boundary Method
!##########################
if (ivirt==1) then
uvisu=0.
call fine_to_coarseV(1,ep1,uvisu)
1000 format('IBM',I4.4)
write(filename, 1000) itime/imodulo
call decomp_2d_write_one(1,uvisu,filename,2)    
endif

!if (jles.gt.1)  then
!uvisu=0.
!call fine_to_coarseV(1,nut1,uvisu)
!1001 format('nuSGS',I4.4)
!write(filename, 1001) itime/imodulo
!call decomp_2d_write_one(1,uvisu,filename,2)    
!endif

if(jles.eq.1.and.dynhypvisc.eq.1) then
uvisu=0.
call fine_to_coarseV(1,rxxnu*shrt_coeff,uvisu)
1002 format('dynvisc',I4.4)
write(filename, 1002) itime/imodulo
call decomp_2d_write_one(1,uvisu,filename,2)    
endif

!############################################################################
!PRESSURE
!IT IS IN A SEPARATE SUBROUTINE
!############################################################################
end subroutine VISU_INSTA


!##############################################################
! PRINT SNAPSHOTS
!##############################################################

subroutine VISU_SNAP(ux1,uy1,uz1,uvisu)
!
!############################################################################

USE param
USE decomp_2d
USE decomp_2d_io

real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ux1,uy1,uz1
real(mytype),dimension(xszV(1),xszV(2),xszV(3)) :: uvisu 
character(len=20) :: filename

uvisu=0.
call fine_to_coarseV(1,ux1,uvisu)
1011 format('snap_ux',I4.4)
      write(filename, 1011) itime/sfreq
call decomp_2d_write_subdomain(1,ux1,simin,simax,sjmin,sjmax,skmin,skmax,filename)
uvisu=0.
call fine_to_coarseV(1,uy1,uvisu)
1012 format('snap_uy',I4.4)
      write(filename, 1012) itime/sfreq
call decomp_2d_write_subdomain(1,uy1,simin,simax,sjmin,sjmax,skmin,skmax,filename)
uvisu=0.
call fine_to_coarseV(1,uz1,uvisu)
1013 format('snap_uz',I4.4)
      write(filename, 1013) itime/sfreq
call decomp_2d_write_subdomain(1,uz1,simin,simax,sjmin,sjmax,skmin,skmax,filename)

if (nrank==0) print *, 'Writing snapshot ', itime/sfreq

end subroutine VISU_SNAP

!############################################################################
!
subroutine STATISTIC(ux1,uy1,uz1,phi1,ta1,umean,vmean,wmean,phimean,uumean,vvmean,wwmean,&
     uvmean,uwmean,vwmean,phiphimean,tmean)
!
!############################################################################

USE param
USE decomp_2d
USE decomp_2d_io
use var, only: di1,di2,ux2,uy2,ta2,tb2,tc2,tauxymean
implicit none

real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ux1,uy1,uz1,phi1
real(mytype),dimension(xszS(1),xszS(2),xszS(3)) :: umean,vmean,wmean,uumean,vvmean,wwmean,uvmean,uwmean,vwmean,tmean
real(mytype),dimension(xszS(1),xszS(2),xszS(3)) :: phimean, phiphimean
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ta1

!umean=ux1
call fine_to_coarseS(1,ux1,tmean)
umean(:,:,:)=umean(:,:,:)+tmean(:,:,:)

!vmean=uy1
call fine_to_coarseS(1,uy1,tmean)
vmean(:,:,:)=vmean(:,:,:)+tmean(:,:,:)

!wmean=uz1
call fine_to_coarseS(1,uz1,tmean)
wmean(:,:,:)=wmean(:,:,:)+tmean(:,:,:)

if (iscalar==1) then
   !phimean=phi1
   call fine_to_coarseS(1,phi1,tmean)
   phimean(:,:,:)=phimean(:,:,:)+tmean(:,:,:)
endif

!uumean=ux1*ux1
ta1(:,:,:)=ux1(:,:,:)*ux1(:,:,:)
call fine_to_coarseS(1,ta1,tmean)
uumean(:,:,:)=uumean(:,:,:)+tmean(:,:,:)

!vvmean=uy1*uy1
ta1(:,:,:)=uy1(:,:,:)*uy1(:,:,:)
call fine_to_coarseS(1,ta1,tmean)
vvmean(:,:,:)=vvmean(:,:,:)+tmean(:,:,:)

!wwmean=uz1*uz1
ta1(:,:,:)=uz1(:,:,:)*uz1(:,:,:)
call fine_to_coarseS(1,ta1,tmean)
wwmean(:,:,:)=wwmean(:,:,:)+tmean(:,:,:)

!uvmean=ux1*uy1
ta1(:,:,:)=ux1(:,:,:)*uy1(:,:,:)
call fine_to_coarseS(1,ta1,tmean)
uvmean(:,:,:)=uvmean(:,:,:)+tmean(:,:,:)

!uwmean=ux1*uz1
ta1(:,:,:)=ux1(:,:,:)*uz1(:,:,:)
call fine_to_coarseS(1,ta1,tmean)
uwmean(:,:,:)=uwmean(:,:,:)+tmean(:,:,:)

!vwmean=uy1*uz1
ta1(:,:,:)=uy1(:,:,:)*uz1(:,:,:)
call fine_to_coarseS(1,ta1,tmean)
vwmean(:,:,:)=vwmean(:,:,:)+tmean(:,:,:)

if (iscalar==1) then
   !phiphimean=phi1*phi1
   ta1(:,:,:)=phi1(:,:,:)*phi1(:,:,:)
   call fine_to_coarseS(1,ta1,tmean)
   phiphimean(:,:,:)=phiphimean(:,:,:)+tmean(:,:,:)
endif

if (jles.ge.2) then
!Computing the shear stresses
!WORK X-PENCILS
call derx (ta1,uy1,di1,sx,ffxp,fsxp,fwxp,xsize(1),xsize(2),xsize(3),1)
!WORK Y-PENCILS
call transpose_x_to_y(ux1,ux2)
call transpose_x_to_y(ta1,ta2)
call dery (tb2,ux2,di2,sy,ffyp,fsyp,fwyp,ppy,ysize(1),ysize(2),ysize(3),1)

tc2(:,:,:)=0.5*(tb2(:,:,:)+ta2(:,:,:))

call transpose_y_to_x(tc2,ta1)
call fine_to_coarseS(1,ta1,tmean)
tauxymean(:,:,:)=tauxymean(:,:,:)+tmean(:,:,:)

endif
!for a verification
!call decomp_2d_write_one(nx_global,ny_global,nz_global,&
!           1,ta1,'compa.dat')

if (mod(itime,isave)==0) then
   call decomp_2d_write_one(1,umean,'umean.dat',1)
   call decomp_2d_write_one(1,vmean,'vmean.dat',1)
   call decomp_2d_write_one(1,wmean,'wmean.dat',1)
   call decomp_2d_write_one(1,uumean,'uumean.dat',1)
   call decomp_2d_write_one(1,vvmean,'vvmean.dat',1)
   call decomp_2d_write_one(1,wwmean,'wwmean.dat',1)
   call decomp_2d_write_one(1,uvmean,'uvmean.dat',1)
   call decomp_2d_write_one(1,uwmean,'uwmean.dat',1)
   call decomp_2d_write_one(1,vwmean,'vwmean.dat',1)
   if (jLES.ge.2) then
   call decomp_2d_write_one(1,tauxymean,'tauxymean.dat',1)
   endif
   if (nrank==0) print *,'write stat arrays velocity done!'
   if (iscalar==1) then
      call decomp_2d_write_one(1,phimean,'phimean.dat',1)
      call decomp_2d_write_one(1,phiphimean,'phiphimean.dat',1)
      if (nrank==0) print *,'write stat arrays scalar done!'
   endif
!   call decomp_2d_write_one(nx_global,ny_global,nz_global,1,ux1,'compa.dat')
   
endif

end subroutine STATISTIC

!############################################################################
!
subroutine VISU_PRE (pp3,ta1,tb1,di1,ta2,tb2,di2,&
     ta3,di3,nxmsize,nymsize,nzmsize,phG,ph2,ph3,uvisu)
!
!############################################################################

USE param
USE decomp_2d
USE decomp_2d_io

implicit none

integer :: nxmsize,nymsize,nzmsize
TYPE(DECOMP_INFO) :: phG,ph2,ph3
real(mytype),dimension(xszV(1),xszV(2),xszV(3)) :: uvisu 

real(mytype),dimension(ph3%zst(1):ph3%zen(1),ph3%zst(2):ph3%zen(2),nzmsize) :: pp3 
!Z PENCILS NXM NYM NZM-->NXM NYM NZ
real(mytype),dimension(ph3%zst(1):ph3%zen(1),ph3%zst(2):ph3%zen(2),zsize(3)) :: ta3,di3
!Y PENCILS NXM NYM NZ -->NXM NY NZ
real(mytype),dimension(ph3%yst(1):ph3%yen(1),nymsize,ysize(3)) :: ta2
real(mytype),dimension(ph3%yst(1):ph3%yen(1),ysize(2),ysize(3)) :: tb2,di2
!X PENCILS NXM NY NZ  -->NX NY NZ
real(mytype),dimension(nxmsize,xsize(2),xsize(3)) :: ta1
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: tb1,di1 

integer :: code,icomplet
integer :: ijk,nvect1,nvect2,nvect3,i,j,k
character(len=20) nfichier,nfichier1
character(len=20) :: filename

!WORK Z-PENCILS
call interiz6(ta3,pp3,di3,sz,cifip6z,cisip6z,ciwip6z,cifz6,cisz6,ciwz6,&
     (ph3%zen(1)-ph3%zst(1)+1),(ph3%zen(2)-ph3%zst(2)+1),nzmsize,zsize(3),1)
!WORK Y-PENCILS
call transpose_z_to_y(ta3,ta2,ph3) !nxm nym nz
call interiy6(tb2,ta2,di2,sy,cifip6y,cisip6y,ciwip6y,cify6,cisy6,ciwy6,&
     (ph3%yen(1)-ph3%yst(1)+1),nymsize,ysize(2),ysize(3),1)
!WORK X-PENCILS
call transpose_y_to_x(tb2,ta1,ph2) !nxm ny nz
call interi6(tb1,ta1,di1,sx,cifip6,cisip6,ciwip6,cifx6,cisx6,ciwx6,&
     nxmsize,xsize(1),xsize(2),xsize(3),1)
!The pressure field on the main mesh is in tb1
!PRESSURE
uvisu=0.
call fine_to_coarseV(1,tb1,uvisu)
990 format('pp',I4.4)
      write(filename, 990) itime/imodulo
call decomp_2d_write_one(1,uvisu,filename,2)
!call decomp_2d_write_one(nx_global,ny_global,nz_global,&
!           1,tb1,filename)

end subroutine VISU_PRE
