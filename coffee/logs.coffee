angular.module 'logs'
  .factory 'logs',->
    icon =
      error:'assets/error.png'
      success:'assets/success.png'
      download:'assets/download.png'
    ret =
      message: (title,body,type)->
        mes = new Notification title,
          icon:icon[type]
          body:body
        setTimeout mes.close.bind(mes),4000
        return
    return ret
