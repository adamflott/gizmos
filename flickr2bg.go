package main

import (
    "encoding/json"
    "fmt"
    "io/ioutil"
    "math/rand"
    "net/http"
    "os"
    "os/exec"
    "os/user"
    "runtime"
    "time"
)

import (
    "github.com/mncaudill/go-flickr"
    "github.com/voxelbrain/goptions"
)

type JSONPhoto struct {
    Id             string
    Owner          string
    Secret         string
    Server         string
    Farm           float64
    Title          string
    Ispublic       float64
    Isfriend       float64
    Isfamily       float64
    Originalformat string
    Originalsecret string
    Url_o          string
}

type JSONPhotos struct {
    Page    float64
    Pages   float64
    Perpage float64
    Total   float64
    Photo   []JSONPhoto
}

type JSONContainer struct {
    Photos JSONPhotos
}

func main() {
    options := struct {
        APIKey        string `goptions:"-k, --key, description='Flickr API Key'"`
        RotateTime    int    `goptions:"-t, --time, description='Change wallpaper in x minutes'"`
        goptions.Help `goptions:"-h, --help, description='Show this help'"`
    }{
        APIKey: "43191244e34b0a7c712f2d2485e8afff",
    }

    goptions.ParseAndFail(&options)

    for {
        r := &flickr.Request{
            ApiKey: options.APIKey,
            Method: "flickr.interestingness.getList",
            Args: map[string]string{
                "format":         "json",
                "nojsoncallback": "1",
                "extras":         "url_o",
            },
        }

        resp, err := r.Execute()
        if err != nil {
            panic(err)
        }

        b := []byte(resp)

        var d JSONContainer
        json.Unmarshal(b, &d)

        // photos with an original URL are more likely to be higher quality
        var photo JSONPhoto
        for {
            rnd := rand.New(rand.NewSource(time.Now().Unix()))
            photo = d.Photos.Photo[rnd.Int31n(int32(len(d.Photos.Photo)))]
            if photo.Url_o != "" {
                break
            }
        }

        u, _ := user.Current()
        var root string = fmt.Sprintf("%s/.flickr2bg", u.HomeDir)

        os.MkdirAll(root, 0700)

        resp2, err2 := http.Get(photo.Url_o)

        if err2 != nil {
            panic(err2)
        }

        defer resp2.Body.Close()
        body, _ := ioutil.ReadAll(resp2.Body)

        fn := fmt.Sprintf("%s/%d.jpg", root, int64(time.Now().Unix()))
        if f, e := os.Create(fn); e == nil {
            f.Write(body)
            f.Close()

            var c *exec.Cmd = nil
            switch runtime.GOOS {
            case "darwin":
                c = exec.Command("osascript", "-e", "tell application \"Finder\"", "-e", fmt.Sprintf("set desktop picture to POSIX file \"%s\"", fn), "-e", "end tell")
            }

            if c != nil {
                c.Run()
            }
        } else {
            panic(e)
        }

        time.Sleep(time.Minute * time.Duration(options.RotateTime))
    }
}
