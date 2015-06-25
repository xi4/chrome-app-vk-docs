service = angular.module 'apps.service',[],($provide)->
  $provide.decorator '$window',($delegate)->
    $delegate.history = null
    return $delegate
  return


#TODO Сервис для работы с апи ВК

service.factory 'VkApi', ($http,$rootScope,logs,$timeout)->
  client_id = '4947127'
  version = '5.34'

  scope = 'docs,friends,messages,offline'
  callback_blank = 'https://oauth.vk.com/blank.html'
  aut_url = 'https://oauth.vk.com/authorize?client_id={client_id}&scope={scope}&redirect_uri={redirect_uri}&display=popup&v={version}&response_type=token'
  method_url = 'https://api.vk.com/method/'

  friend = [];
  access_token = null;
  docsList = [];

  self =
    getAllFriend:->
      friend
    loadFriend:->
      self.api 'friends.get',
        name_case:'ins'
        fields:'nickname'
      ,(data)->
        friend = data.response.items
        return
      return
    delFile:(file)->
      self.api 'docs.delete',
        owner_id:file.owner_id
        doc_id:file.id
      ,(data)->
        $rootScope.$broadcast('del_file',data)
        return
      return
    loadDocs:->
      self.api 'docs.get',{},(data)->
        if not data.error
          docsList = data.response.items
          $rootScope.$broadcast('docsList:load')
          return
        else
          self.errorParse data
          return
      return
    getAllDocs:->
      docsList
    errorParse:(response)->
      self.auth() if response.error.error_code == 5
      return
    getUrl:->
      url = aut_url
      url = url.replace('{client_id}', client_id)
      url = url.replace('{scope}', scope)
      url = url.replace('{redirect_uri}', callback_blank)
      url = url.replace('{version}', version)
      return url
    GVP:(url,parameterName)->
      urlParameters = url.substr(url.indexOf('#')+1)
      urlParameters = urlParameters.split "&"
      for i in [0...urlParameters.length]
        temp = urlParameters[i].split "="
        parameterValue = temp[1] if temp[0] == parameterName
      return parameterValue
    auth:->
      webview = angular.element(document.querySelector('#auth_win'))[0]
      container = angular.element(document.querySelector('.container-fluid'))[0]
      webview.setAttribute('src',self.getUrl())
      webview.classList.remove('hidden');
      container.classList.add('hidden');
      loadstop = ->
        url = webview.getAttribute('src')
        if url.indexOf('oauth.vk.com/blank.html#access_token=') > -1
          access_token = self.GVP(url,'access_token')
          chrome.storage.local.set({'access_token':access_token},->
            webview.classList.add('hidden')
            container.classList.remove('hidden')
            self.loadDocs()
            return
          )
          return
      webview.addEventListener('loadstop',loadstop)
      webview.reload()
      return
    objToStr:(obj)->
      str=''
      angular.forEach(obj,(value,key)->
        str+=key+'='+value+'&'
        return
      )
      return str
    api:(method,data,callback)->
      chrome.storage.local.get 'access_token',(item)->
        if item.access_token != '' || item.access_token != undefined
          $timeout ->
            $http.get(method_url + method + '?' + self.objToStr(data) + 'access_token='+ item.access_token + '&v='+version)
            .success(callback)
            .error ->
              logs.message 'Ошибка','Сервер ВКонтакте не отвечает','error'
              return
            return
          ,2000
          return
      return
    sendFile:(file)->
      self.api 'docs.getUploadServer',{},(data)->
        if not data.error
          url = data.response.upload_url
          xhr = new XMLHttpRequest();
          form = new FormData();
          form.append "file", file, file.name
          xhr.open "POST",url,true
          xhr.onload = ->
            self.api "docs.save",
              file: JSON.parse(xhr.response).file
            ,(data)->
              if not data.error
                logs.message 'Внимание', 'Загрузка файла ' + file.name + ' успешно завершена','success'
                $rootScope.$broadcast 'sendFile:true'
                $rootScope.$broadcast 'addFile:data',data.response[0]
                return
              else
                self.errorParse data
                $rootScope.$broadcast 'sendFile:true'
                logs.message 'Ошибка', 'Файл является недопустимым для загрузки','error'
                return
            return
          xhr.onreadystatechange = ->
            if xhr.readyState == 2 or xhr.readyState == 3 of xhr.readyState == 4
              if xhr.status == 502
                xhr.abort()
                $rootScope.$broadcast 'sendFile:false',file
                return
          xhr.send form
          return
      return
  return self

#TODO Функция для вывода сообщений пользователю
service.factory 'logs',->
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

#TODO разные утилиты
service.factory 'utils',($http)->
  utils =
    sizeFormat:(bytes)->
      sizes = [
        'Bytes'
        'KB'
        'MB'
        'GB'
        'TB'
      ]
      return '0 Byte' if bytes == 0
      i = parseInt Math.floor(Math.log(bytes) / Math.log(1024))
      return Math.round(bytes / Math.pow(1024, i), 2) + ' ' + sizes[i]
    getImgData:(url)->
      imgData = {}
      utils.getBlob url,(data)->
        imgData = window.URL.createObjectURL(data)
        return
      return imgData
    getBlob:(url,callback)->
      $http.get(url,responseType:'blob')
      .success(callback)
      .error (data)->
        console.log(data)
        return
      return
    downloadFile:(file)->
      utils.getBlob file.url,(blob)->
        chrome.storage.local.get 'selDir', (item)->
          chrome.fileSystem.isRestorable item.selDir, (selDir)->
            if selDir
              chrome.fileSystem.restoreEntry item.selDir, (entry)->
                entry.getFile file.title, {create: true}, (ent)->
                  ent.createWriter (writer)->
                    writer.write blob
                    chrome.fileSystem.getDisplayPath entry, (path)->
                      logs.message file.title, 'Файл успешно сохранент в папку: \n' + path, 'download'
            else
              logs.message 'Ошибка', 'Папка для сохранения файла не выбрана!\nДля выбора папки воспользуйтесь настройками.', 'error'
  return utils