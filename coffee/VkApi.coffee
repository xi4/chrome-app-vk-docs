angular.module 'VkApi'
  .factory 'VkApi',($http,$rootScope,logs,$timeout)->
    client_id = '4947127'
    version = '5.34'

    scope = 'docs,friends,messages,offline'
    callback_blank = 'https://oauth.vk.com/blank.html'
    aut_url = 'https://oauth.vk.com/authorize?client_id={client_id}&scope={scope}&redirect_uri={redirect_uri}&display=popup&v={version}&response_type=token'
    method_url = 'https://api.vk.com/method/'

    friend = [];
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
            utils.errorParse data
            return
        return
      getAllDocs:->
        docsList
      auth:->
        webview = angular.element(document.querySelector('#auth_win'))[0]
        container = angular.element(document.querySelector('.container-fluid'))[0]
        webview.setAttribute('src',self.getUrl())
        webview.classList.remove('hidden');
        container.classList.add('hidden');
        loadstop = ->
          url = webview.getAttribute('src')
          if url.indexOf('oauth.vk.com/blank.html#access_token=') > -1
            access_token = utils.GVP(url,'access_token')
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
      api:(method,data,callback)->
        chrome.storage.local.get 'access_token',(item)->
          if item.access_token != '' || item.access_token != undefined
            $timeout ->
              $http.get(method_url + method + '?' + utils.objToStr(data) + 'access_token='+ item.access_token + '&v='+version)
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
                  utils.errorParse data
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
